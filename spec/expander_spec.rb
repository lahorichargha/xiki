$:.unshift "spec/"

%w"xiki/core_ext xiki/ol xiki/menu xiki/file_tree xiki/bookmarks".each {|o| require o}


# TODO: move this into spec_helper, and make it get real xiki dir?
# module Xiki
#   def self.dir; end
# end

require 'xiki/expander'
require 'xiki/pattern'

require './spec/spec_helper'

# describe Expander, "#expand" do
describe Expander, "#extract_ancestors" do
  it "pulls out one path" do
    args = "a/@b/", {}
    Expander.extract_ancestors *args
    args.should == ["b/", {:ancestors=>["a/"]}]
  end

  it "works when no nesting" do
    args = "a/b/", {}
    Expander.extract_ancestors *args
    args.should == ["a/b/", {}]
  end

  it "ignores quoted path" do
    args = "a/| a/@b/", {}
    Expander.extract_ancestors *args
    args.should == ["a/| a/@b/", {}]
  end
end

describe Expander, "#expand_file_path" do
  it "expands dot" do
    Expander.expand_file_path("../a").should =~ %r"\w+/a$"
    Expander.expand_file_path("./a").should =~ %r"\w+/a$"
  end

  it "expands home dir" do
    Expander.expand_file_path("~/a").should =~ %r"\w+/a$"
  end

  it "expands bookmarks" do
    stub(Bookmarks).[]("$d") {"/tmp/dir/"}
    Expander.expand_file_path("$d/a//b").should == "/tmp/dir/a//b"
    Expander.expand_file_path("$d").should == "/tmp/dir"
    Expander.expand_file_path("$d/").should == "/tmp/dir/"
  end

  it "doesn't remove double slashes for home and current dir" do
    Expander.expand_file_path("./a//b").should =~ %r"a//b"
    Expander.expand_file_path("~/a//b").should =~ %r"a//b"
  end

  it "doesn't remove double slashes for bookmarks" do
    stub(Bookmarks).[]("$f") {"/tmp/file.txt"}
    Expander.expand_file_path("$f//").should == "/tmp/file.txt//"
  end
end

describe Expander, "#parse" do

  it "handles pure dir paths" do
    Expander.parse("/tmp/a/b/").should ==
      {:file_path=>"/tmp/a/b/"}
  end

  it "just passes through when input already a hash" do
    Expander.parse(:foo=>"bar").should ==
      {:foo=>"bar"}
  end

  it "handles file paths" do
    Expander.parse("/tmp/a/b").should ==
      {:file_path=>"/tmp/a/b"}
  end

  it "handles menufied paths" do
    Expander.parse("/tmp/a//").should ==
      {:menufied=>"/tmp/a"}
  end

  it "handles menufied path with items" do
    Expander.parse("/tmp/a//b/").should ==
      {:menufied=>"/tmp/a", :items=>["b"]}
  end

  it "handles name that looks kind of menufied" do
    Expander.parse("a/http://notmenufied.com/").should ==
      {:name=>"a", :items=>["http:", "", "notmenufied.com"],
       :path=>"a/http://notmenufied.com/"
      }
  end

  it "handles filesystem root menufied path" do
    Expander.parse("//").should ==
      {:menufied=>"/"}
  end

  it "handles names" do
    Expander.parse("a").should ==
      {:name=>"a", :path => "a"}
  end

  it "handles name with items" do
    Expander.parse("a/b/c/").should ==
      {:name=>"a", :items=>["b", "c"], :path => "a/b/c/"}
  end

  it "handles name with quoted items" do
    Expander.parse("a/| hi").should ==
      {:name=>"a", :items=>["| hi"], :path => "a/| hi"}
  end

  it "handles name with quoted slash" do
    Expander.parse("a/| foo/yau").should ==
      {:name=>"a", :items=>["| foo/yau"], :path => "a/| foo/yau"}
  end

  it "handles patterns" do
    Expander.parse("select * from users").should ==
      {:path=>"select * from users"}
  end

  it "handles pattern that looks kind of like a file path" do
    Expander.parse("/user@site.com/a/").should ==
      {:path=>"/user@site.com/a/"}
  end

  it "handles name with list of items" do
    Expander.parse("a", ["a", "b"]).should ==
      {:name=>"a", :items=>["a", "b"], :path => "a"}
  end

  it "handles symbol with list of items" do
    Expander.parse(:a, ["a", "b"]).should ==
      {:name=>"a", :items=>["a", "b"]}
  end

  it "handles ancestors in string" do
    Expander.parse("z/@a/").should ==
      {:name=>"a", :ancestors=>["z/"], :path => "a/"}
  end

  it "handles ancestors with path in string" do
    Expander.parse("x/y/@a/b/").should ==
      {:name=>"a", :items=>["b"], :ancestors=>["x/y/"], :path => "a/b/"}
  end

  it "pulls out ancestors when first arg is array" do
    Expander.parse(["x/y/", "m/n/", "a/b/"]).should ==
      {:name=>"a", :items=>["b"], :ancestors=>["x/y/", "m/n/"],
       :path => "a/b/"
      }
  end

  it "doesn't create ancestors when first arg is array of size 1" do
    Expander.parse(["a/b/"]).should ==
      {:name=>"a", :items=>["b"], :path => "a/b/"}
  end

end


describe Expander, "#expand method" do
  before(:each) do
    stub_menu_path_env_dirs   # Has to be before each for some reason
  end

  it "expands when no path" do
    Expander.def(:echo) { |path| path.inspect }
    Expander.expand("echo").should == '[]'
  end

  it "expands when path" do
    Expander.def(:echo) { |path| path.inspect }
    Expander.expand("echo/a").should == '["a"]'
  end

  it "takes a path list as 2nd arg" do
    Ol["Maybe pull 'echo' out as its own menu - and pass options to make it cached?!"]
    Expander.def(:echo) { |path| path.inspect }

    Expander.expand("echo", ["a", "b"]).should == '["a", "b"]'
  end

  it "expands menu in MENU_PATH" do
    Expander.expand("dd").should == "+ a/\n+ b/\n+ cccc/"
  end

  it "expands plain file path" do
    Expander.expand("#{Xiki.dir}spec/fixtures/menu/dr/").should == "+ a.rb\n+ b.rb\n"
  end

  it "expands menufied path" do
    Expander.expand("#{Xiki.dir}spec/fixtures/menu/dr//").should == "+ a/\n+ b/\n"
  end

end
