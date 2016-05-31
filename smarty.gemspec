# -*- encoding: utf-8 -*-
$LOAD_PATH << File.dirname(__FILE__) + "/lib"
require 'smarty/version'

Gem::Specification.new do |s|
  s.name        = "smarty"
  s.version     = Smarty::VERSION
  s.authors     = ["Best Codeo Team"]
  s.email       = ["mike@carbonfive.com"]
  s.homepage    = ""
  s.summary     = %q{}
  s.description = %q{}

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_runtime_dependency "slacky", ">= 0.2.1"
  s.add_runtime_dependency "elasticsearch"

  s.add_development_dependency 'rake'
  s.add_development_dependency 'minitest'
  s.add_development_dependency 'factory_girl'
end
