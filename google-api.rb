#!/usr/bin/env ruby

$:.unshift(File.expand_path("../lib", __FILE__))

require 'thor'
require 'dotenv'


# Small script to allow executing samples from the command line.
# Each sample is loaded as a subcommand.
#
# Example usage:
#
#     google-api-samples drive upload myfile.txt
#
#
class App < Thor

  # Load all the samples and register them as subcommands
  Dir.glob('./lib/cleaner/*.rb').each do |file|
    require file
  end

  Cleaner.constants.each do |const|
    desc const.downcase, "#{const} samples"
    subcommand const.downcase, Cleaner.const_get(const)
  end

end

Dotenv.load
App.start(ARGV)
