# coding: utf-8

# This is a stub for easy profiling of Wikiblame.


require 'ruby-prof'
require_relative 'wikiblame'

$VERBOSE = true

unless File.directory? 'profile'
	Dir.mkdir 'profile'
end

# WikiBlame.new lang, article, reverts, collapse, revertshard, pilcrow, parsed, colorusers, granularity
# blame = WikiBlame.new 'pl', 'Zaginiona flota', true, true, true, false, false, false, 'chars'
blame = WikiBlame.new 'pl', 'Automatyka domowa', true, true, true, false, false, false, 'chars'


RubyProf.start
at_exit {
	result = RubyProf.stop
	RubyProf::FlatPrinter.new(result).print(STDOUT)
	# RubyProf::DotPrinter.new(result).print(f=File.open('profile/graph.dot', 'w')); f.close
	# system "dot -Tsvg -o profile/graph.svg profile/graph.dot"
	RubyProf::CallStackPrinter.new(result).print(f=File.open('profile/graph.html', 'w')); f.close
}


blame.blame
