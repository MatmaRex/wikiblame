# coding: utf-8

# This is a stub for basic regression testing of Wikiblame.

require_relative 'wikiblame'

articles = [
	'Zaginiona flota',
	'Automatyka domowa',
	'Motorola DynaTAC',
	'Samy Naceri',
	'Erupcja wulkanu',
	'Pantomogram',
]

unless File.directory? './test'
	Dir.mkdir './test'
end

articles.each do |art|
	fname = "./test/#{art}.html"
	
	new = WikiBlameCamping.get(:Diff, :request => {'lang' => 'pl', 'article' => art}).get
	if File.exist? fname
		old = File.binread(fname).force_encoding('utf-8')
		
		old_time = new_time = nil
		bad = 
			old.sub(/Rendered in ([\d.]+) seconds\./){old_time = $1; ''} != new.sub(/Rendered in ([\d.]+) seconds\./){new_time = $1; ''}
		;
		
		puts "#{art}: #{bad ? 'bad' : 'good'}; time: #{old_time} -> #{new_time}"
		
		if bad
			File.binwrite(fname.sub(/\.html$/, '_bad\&'), new)
		end
	else
		new_time = new[/Rendered in ([\d.]+) seconds\./, 1]
		puts "#{art}: time: #{new_time}"
		
		File.binwrite(fname, new)
	end
end
