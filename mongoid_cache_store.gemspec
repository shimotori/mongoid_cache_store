# -*- encoding: utf-8 -*-

Gem::Specification.new do |gem|
  gem.authors       = ["iwazer"]
  gem.email         = ["iwazawa@gmail.com"]
  gem.description   = %q{This gem makes it possible to use MongoDB as Rails cache_store. Use Mongoid as a driver to connect to MongoDB.}
  gem.summary       = %q{Make it possible to use MongoDB as Rails cache_store through Mongoid.}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "mongoid_cache_store"
  gem.require_paths = ["lib"]
  gem.version       = "0.1.2"

  gem.add_dependency("activesupport", ["~> 3.2"])
  gem.add_dependency("mongoid", ["~> 3.0"])
end
