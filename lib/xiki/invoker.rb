class Invoker
  # Invokes actions on menu source classes.
  #
  # The actioun is often the .menu method, but could alternateyl be handled
  # by the MENU constant or the foo.menu file.  Also, MENU or foo.menu may route
  # to a different method, in which case that will be invoked.
  def self.invoke clazz, args, options={}

    args ||= []
    menu_found = false   # Will be true if found MENU constant, .menu method, or .menu file

    code, clazz_name, dot_menu_file = options[:code], options[:clazz_name], options[:dot_menu_file]

    # Load class...

    # Assume clazz is a file for now

    # Just always reload for now (no caching)
    returned, out, exception = Code.eval code, clazz, 1, :global=>1

    # TODO: wrap modules around depending on dir (based on :last_source_dir)?

    clazz = Code.simple_eval("defined?(#{clazz_name}) ? #{clazz_name} : nil", nil, nil, :global=>1)

    # Call .menu_before if exists...

    method = clazz.method("menu_before") rescue nil

    if method
      code = "#{clazz_name}.menu_before *#{args.inspect}"

      # Did :global this break stuff?
      returned, out, exception = Code.eval code, nil, nil, :global=>1

      return CodeTree.draw_exception exception, code if exception
      if returned   # If they handled it, go no further
        returned = returned.unindent if returned =~ /\A[ \n]/
        return returned
      end
    end

    # Grab MENU constant or .menu file...

    if clazz.const_defined? :MENU
      menu_found = true
      menu_text = clazz::MENU
    elsif File.file?(dot_menu_file)
      menu_found = true
      menu_text = File.read dot_menu_file
    end

    txt = nil

    # If MENU|foo.menu, do routing (get children or dotify)...

    dotified = []

    if menu_text

      menu_text = menu_text.unindent if menu_text =~ /\A[ \n]/

      txt = Tree.children menu_text, args

      # If there was output use it, otherwise try routing (dotifying)

      if ! txt || txt == "- */\n"
        dotified = Tree.dotify menu_text, args
      end
    end

    # If MENU_HIDDEN exists, use it to route...

    menu_hidden = clazz.const_defined? "MENU_HIDDEN"
    if menu_hidden
      returned = clazz.const_get "MENU_HIDDEN"
      dotified = Tree.dotify returned.unindent, args
    end

    # If MENU|foo.menu not found or didn't handle path, call routed method or otherwise .menu with args...

    if ! txt

      # Figure out whether to try .menu or routed .method
      action, variables = self.actionify args, dotified

      menu_found = true if clazz.method(action) rescue nil   # Method exists, so call it

      # If no menu or routed method of any kind, try menuless mode...

      if ! menu_found
        cmethods = clazz.methods - Class.methods
        options[:instance_method] = 1 if cmethods.empty?

        if args.empty?   # /, so list all methods
          # If MENU|foo.menu|Foo.menu, just show all methods, and call method based on name...

          # Pass instance methods if none
          cmethods = clazz.instance_methods - Class.instance_methods if cmethods.empty?

          txt = cmethods.sort.map{|o| "+ #{o}/\n"}.join ""

        else   # /foo/bar, so invoke /.foo/bar!
          # Artificially route to 1st item to be the action
          dotified = [true]   # Indicate only the first item is the action
          action, variables = self.actionify args, dotified
        end

      end

      # If still no text, try .menu or routed method...

      if ! txt
        action_method =
          if options[:instance_method]
            clazz.new.method(action) rescue nil
          else
            clazz.method(action) rescue nil
          end

        if action_method   # Method exists, so call it
          menu_found = true # = :method

          # Call action...

          code = proc{ action_method.call(*variables) {options} }
          txt, out, exception = Code.eval code

          txt = CodeTree.returned_to_s(txt)   # Convert from array into string, etc.
          txt = txt.unindent if txt =~ /\A[ \n]/

          if exception
            args = variables.map{|o| "\"#{CodeTree.escape o}\""}.join(", ")   # This was only when we eval'ed
            code = "#{clazz_name}.#{action} #{args}".strip
            return CodeTree.draw_exception exception, code
          end

        else

          # TODO: No menu or other method found, so suggest creating new?...
          raise "no menu or class method found for this menu!"

        end
      end
    end


    # TODO: Be sure to eval output that starts with "! "
      # When?
        # Even when self.menu output?


    #     # TODO: Unified: comment out for now - just comment out since we're doing no caching
    #     # reload 'path_to_class'
    #     Menu.load_if_changed File.expand_path("~/menu/#{snake}.rb")


    # Call .menu_after if it exists...

    method = clazz.method("menu_after") rescue nil
    return txt if method.nil?

    code = "#{clazz_name}.menu_after #{txt.inspect}, *#{args.inspect}"
    returned, out, exception = Code.eval code, nil, nil, :global=>1

    return CodeTree.draw_exception exception, code if exception
    if returned
      txt = returned.unindent if returned =~ /\A[ \n]/
    end

    txt
  end


  # Breaks args down into a method ("action") and the params
  # Invoker.actionify(["act", "b"], [true])
  #   ["act", ["b"]]
  def self.actionify args, boolean_array

    # Last .dotted one is the action, and non-dotted are variables to pass

    i = -1
    actions, variables = args.partition{|o|
      i += 1
      boolean_array[i]
    }

    action = actions.last || "menu"
    action.gsub! /[ -]/, '_'
    action.gsub! /[^\w.]/, ''

    action.downcase!

    [action, variables]
  end

end
