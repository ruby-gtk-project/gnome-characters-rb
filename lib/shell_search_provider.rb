# frozen_string_literal: true

require 'adwaita'
require_relative 'gc'
require_relative 'util'

# ShellSearchProvider is the port of upstream's src/searchProvider.js and the
# interface it exports, data/ShellSearchProvider2.xml.
#
# It answers org.gnome.Shell.SearchProvider2:
#
#   GetInitialResultSet(as)       -> as       characters matching the terms
#   GetSubsearchResultSet(as, as) -> as       the same, narrowed
#   GetResultMetas(as)            -> aa{sv}   name, id, description, icon data
#   ActivateResult(s, as, u)                  notify that it was copied
#   LaunchSearch(as, u)                       open the window on that search
#
# Upstream searches in a thread and returns the D-Bus call from the search
# callback. Here the search runs on the main loop in slices, and the
# invocation is likewise held until the search finishes, so the shell sees the
# same asynchronous behaviour.
class ShellSearchProvider
  INTERFACE = 'org.gnome.Shell.SearchProvider2'
  MAX_SEARCH_RESULTS = 20

  NODE_XML = <<~XML
    <node>
      <interface name="org.gnome.Shell.SearchProvider2">
        <method name="GetInitialResultSet">
          <arg type="as" name="terms" direction="in"/>
          <arg type="as" name="results" direction="out"/>
        </method>
        <method name="GetSubsearchResultSet">
          <arg type="as" name="previous_results" direction="in"/>
          <arg type="as" name="terms" direction="in"/>
          <arg type="as" name="results" direction="out"/>
        </method>
        <method name="GetResultMetas">
          <arg type="as" name="identifiers" direction="in"/>
          <arg type="aa{sv}" name="metas" direction="out"/>
        </method>
        <method name="ActivateResult">
          <arg type="s" name="identifier" direction="in"/>
          <arg type="as" name="terms" direction="in"/>
          <arg type="u" name="timestamp" direction="in"/>
        </method>
        <method name="LaunchSearch">
          <arg type="as" name="terms" direction="in"/>
          <arg type="u" name="timestamp" direction="in"/>
        </method>
      </interface>
    </node>
  XML

  def initialize(application, on_launch_search: nil)
    @application = application
    @on_launch_search = on_launch_search
  end

  # export(connection, path): the same registration upstream does from
  # vfunc_dbus_register, at <object path>/SearchProvider.
  def export(connection, path)
    interface_info.then do |interface|
      connection.register_object(path, interface, method(:handle_method_call))
    end
  rescue StandardError, GLib::Error => e
    warn "Could not export the search provider: #{e.message}"
    nil
  end

  # lookup_interface rather than interfaces.first: Gio::DBusNodeInfo#interfaces
  # returns unusable strings in these bindings, while #lookup_interface returns
  # the Gio::DBusInterfaceInfo wanted here.
  def interface_info = Gio::DBusNodeInfo.new(NODE_XML).lookup_interface(INTERFACE)

  def result_metas(identifiers)
    identifiers.filter_map { |character| meta_for(character) }
  end

  def activate_result(_identifier, _terms, _timestamp)
    @application.send_notification(nil, activation_notification)
  end

  def launch_search(terms, timestamp)
    @application.activate
    @on_launch_search&.call(terms, timestamp)
  end

  private

    def handle_method_call(_connection, _sender, _path, _interface, method_name, parameters, invocation)
      case method_name
      when 'GetInitialResultSet'
        run_query(string_list(parameters, 0), invocation)
      when 'GetSubsearchResultSet'
        run_query(string_list(parameters, 1), invocation)
      when 'GetResultMetas'
        invocation.return_value(metas_variant(result_metas(string_list(parameters, 0))))
      when 'ActivateResult'
        activate_result(parameters.get_child_value(0).value, [], 0)
        invocation.return_value(nil)
      when 'LaunchSearch'
        launch_search(string_list(parameters, 0), parameters.get_child_value(1).value)
        invocation.return_value(nil)
      end
    rescue StandardError, GLib::Error => e
      warn "Search provider call #{method_name} failed: #{e.message}"
      invocation.return_value(nil)
    end

    def string_list(parameters, index) = Array(parameters.get_child_value(index).value)

    # The application is held for as long as the search runs, so a service
    # instance started only for the shell does not exit mid-search.
    def run_query(terms, invocation)
      @application.hold
      @context&.cancel
      @characters = []
      Gc::SearchContext.new(criteria_for(terms), flags: [:word]).tap do |context|
        @context = context
        context.search(
          max_matches: MAX_SEARCH_RESULTS,
          on_batch:    method(:collect),
          on_finished: ->(_total) { finish_query(invocation) },
        )
      end
    end

    def criteria_for(terms) = Gc::SearchCriteria.keywords(terms.map(&:upcase))

    def collect(batch)
      @characters.concat(Gc.search_result_to_array(batch))
    end

    def finish_query(invocation)
      invocation.return_value(string_array(@characters))
      @application.release
    end

    def meta_for(character)
      Util.character_to_icon_data(character).then do |icon_data|
        if icon_data
          {
            'name'          => quote(meta_name(character)),
            'id'            => quote(character),
            'description'   => quote(meta_description(character)),
            'clipboardText' => quote(character),
            'icon-data'     => icon_data.to_s,
          }
        end
      end
    end

    def meta_name(character)
      Gc.character_name(character).then do |name|
        if name
          Util.capitalize(name)
        else
          'Unknown character name'
        end
      end
    end

    def meta_description(character)
      if Gc.character_is_composite?(character)
        ''
      else
        format('U+%X', Util.to_code_point(character))
      end
    end

    # Reply variants are built by parsing GVariant text: GLib::Variant.new in
    # these bindings raises NotImplementedError both for a dictionary and for
    # the tuple a D-Bus reply has to be, and GLib::Variant.parse handles both.
    # The values in a meta are already GVariant text, icon-data included.
    def string_array(values)
      GLib::Variant.parse("([#{values.map { |value| quote(value) }.join(', ')}],)", '(as)')
    end

    def metas_variant(metas)
      GLib::Variant.parse("([#{metas.map { |meta| meta_text(meta) }.join(', ')}],)", '(aa{sv})')
    end

    def meta_text(meta)
      "{#{meta.map { |key, value| "#{quote(key)}: <#{value}>" }.join(', ')}}"
    end

    # GVariant text format uses the same string escapes as C. The block form of
    # gsub is deliberate: backslashes in a replacement string are themselves
    # interpreted, which makes the escaping of an escape character unreadable.
    ESCAPES = { '\\' => '\\\\', '"' => '\\"' }.freeze

    def quote(value) = %("#{value.to_s.gsub(/[\\"]/) { |char| ESCAPES.fetch(char) }}")

    def activation_notification
      Gio::Notification.new('Character copied').tap do |notification|
        notification.body = 'Character was copied successfully'
      end
    end
end
