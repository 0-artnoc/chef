gemspec = eval(File.read(File.expand_path("../mixlib-shellout.gemspec", __FILE__)))

gemspec.platform = Gem::Platform.new(["universal", "mingw32"])

gemspec.add_dependency "win32-process", "~> 0.7.5"

gemspec
