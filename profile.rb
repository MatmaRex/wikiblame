# coding: utf-8

# This is a stub for easy profiling of Wikiblame.


require 'ruby-prof'
require_relative 'wikiblame'


# WikiBlame.new lang, article, reverts, collapse, revertshard, pilcrow, parsed, colorusers, granularity
# blame = WikiBlame.new 'pl', 'Zaginiona flota', true, true, true, false, false, false, 'chars'
blame = WikiBlame.new 'pl', 'Automatyka domowa', true, true, true, false, false, false, 'chars'


RubyProf.start
at_exit {
	result = RubyProf.stop
	RubyProf::FlatPrinter.new(result).print(STDOUT)
	# RubyProf::DotPrinter.new(result).print(f=File.open('graph.dot', 'w')); f.close
	# system "dot -Tsvg -o graph.svg graph.dot"
	RubyProf::CallStackPrinter.new(result).print(f=File.open('graph.html', 'w')); f.close
}


blame.blame
