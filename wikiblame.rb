# WikiBlame v 0.2 by Matma Rex
# matma.rex@gmail.com
# released under CC-BY-SA 3.0


# some code in this file is very old. beware. 
# namely, StringWithMarks class will leave its mark on your mind.
# forever.


# this is a nasty fix. some versions of Markaby want to undef these methods, 
# and some versions of Builder do not define them,
# thus causing an exception. 
require 'builder'
class Builder::BlankSlate
	unless method_defined? :to_s; def to_s; end; end
	unless method_defined? :inspect; def inspect; end; end
	unless method_defined? :==; def ==; end; end
end


require './algo-diff.rb'
require 'sunflower'
require 'camping'


# use local userdata file
def Sunflower.path
	'./sunflower-userdata'
end


Camping.goes :WikiBlameCamping

module WikiBlameCamping
	module Controllers
		class Index
			def get
				@title = "Wiki blame"
				render :index
			end
		end
		
		class SourceX
			def get file
				@headers['content-type']='text/plain'
				
				case file
				when 'wikiblame.rb'
					@source1||=File.read './wikiblame.rb'
				when 'algo-diff.rb'
					@source2||=File.read './algo-diff.rb'
				else
					'Nope.'
				end
			end
		end
		
		class Diff
			def get
				lang = (@request['lang'] and @request['lang']!='') ? @request['lang'] : 'pl'
				article = (@request['article'] and @request['article']!='') ? @request['article'] : ''
				reverts = (@request['reverts'] and @request['reverts']!='') ? true : false
				collapse = (@request['collapse'] and @request['collapse']!='') ? true : false
				revertshard = (@request['revertshard'] and @request['revertshard']!='') ? true : false
				pilcrow = (@request['pilcrow'] and @request['pilcrow']!='') ? true : false
				parsed = (@request['parsed'] and @request['parsed']!='') ? true : false
				colorusers = (@request['colorusers'] and @request['colorusers']!='') ? true : false
				
				
				blame = WikiBlame.new lang, article, reverts, collapse, revertshard, pilcrow, parsed, colorusers
				
				@parsed = parsed
				@title = "#{article} - Wiki blame"
				@css, @legendhtml, @articlehtml = blame.blame
				
				render :diff
			end
		end
	end
	
	module Views
		def layout
			text '<!DOCTYPE html>'
			html do
				head do
					title @title
				end
				body do
					yield
				end
			end
		end
		
		def _input text, name, default=''
			label text, :for=>name
			input id:name, value:default
		end
		
		def _checkbox text, name, checked=false
			label text, :for=>name
			
			if checked
				input id:name, type:'checkbox', checked:'checked'
			else
				input id:name, type:'checkbox'
			end
		end
		
		def index
			#style 'label{display:block}', type:"text/css"
			
			form action:'/diff', method:'get' do
				ul do
					li{ _input 'Wiki language code: ', :lang, 'pl' }
					li{ _input 'Article name: ', :article }
				end
				
				ul do
					li{ _checkbox 'Exclude reverts? ', :reverts, true }
					li{ _checkbox 'Exclude reverts *hard*? (Compare every two revisions) ', :revertshard, true }
					li{ _checkbox 'Collapse subsequent revisions by the same user? ', :collapse, true }
					li{ _checkbox 'Assign unique colors to users instead of revisions? ', :colorusers, false }
				end
				
				ul do
					li{ _checkbox 'Show parsed HTML instead of wikitext? (Warning: may break stuff) ', :parsed, false }
					li{ _checkbox 'Insert pilcrow at newlines? ', :pilcrow, false }
				end
				
				input type:'submit'
				
				p{"WikiBlame v 0.2 by Matma Rex (matma.rex@gmail.com). Released under CC-BY-SA 3.0. Read the source: #{a 'main file', :href=>R(SourceX, 'wikiblame.rb')}, #{a 'algorithm file', :href=>R(SourceX, 'algo-diff.rb')}."}
			end
		end
		
		def diff
			# do something with @css...
			
			div style:'border:1px solid black; margin:5px; padding:5px; float:right' do
				text @legendhtml
			end
			
			div style:(@parsed ? '' : 'white-space:pre-wrap; font-family:monospace') do
				text @articlehtml
			end
		end
	end
end

# class Sunflower
	# def API(request, cache=false)
		# if cache
			# fname = 'cache-'+request.gsub(/[^a-zA-Z0-9]/,'_')+'.txt'
			# if File.exist? fname
				# return JSON.parse(File.read fname)
			# end
		# end
		
		# self.log 'http://'+@wikiURL+'/w/api.php?'+request+'&format=jsonfm'
		# http = HTTP.start(@wikiURL)
		# resp = http.request(HTTP::Post.new('/w/api.php', @headers), request+'&format=json')
		# data = resp.body.to_s
		
		# if cache
			# File.open(fname,'w'){|f| f.write data}
		# end
		
		# JSON.parse(resp.body.to_s)
	# end
# end

class WikiBlame
	def initialize lang, article, reverts, collapse, revertshard, pilcrow, parsed, colorusers
		@lang, @article, @reverts, @collapse, @revertshard, @pilcrow, @parsed, @colorusers = lang, article, reverts, collapse, revertshard, pilcrow, parsed, colorusers
	end
	
	def get_colors n
		if n<=9
			# generate mostly unique colors, based on their hue; 1 shade for each hue
			
			hues = n
			colors = (1..hues).map{|i| (i.to_f/hues*360).floor} # calculate the hues; from 1, so we do not "wrap over" the wheel

			colors = colors.map{|hue| "hsl(#{hue}, 100%, 35%)"}
		else
			# generate mostly unique colors, based on their hue; allow 3 shades for each hue
			
			hues = (n.to_f / 3).ceil # make sure there is just enough
			colors = (1..hues).map{|i| (i.to_f/hues*360).floor} # calculate the hues; from 1, so we do not "wrap over" the wheel

			colors = colors.map{|c| [[c, 35], [c, 55], [c, 75]]}.flatten.each_slice(2).to_a # convert each hue to three hue-lightness pairs
			colors = colors.map{|hue, lightness| "hsl(#{hue}, 100%, #{lightness}%)"}
		end
		
		colors[0...n]
	end
	
	def html_escape text
		text.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;')
	end
	
	def blame
		s=Sunflower.new @lang+'.wikipedia.org'
		s.warnings=false
		s.log=false

		versions=s.API("action=query&prop=revisions&titles=#{CGI.escape @article}&rvlimit=500&rvprop=#{CGI.escape "#{@parsed ? '' : 'content|'}timestamp|user|comment|ids"}&rvdir=newer")
		versions=versions['query']['pages'].values[0]['revisions']
		versions=versions.map do |r| 
			Version[
				html_escape(r['*'].to_s).gsub(/\r?\n/, "#{@pilcrow ? '&para;' : ''}\n"), 
				html_escape(r['user']), 
				r['timestamp'], 
				html_escape(r['comment']),
				nil,
				nil,
				r['revid']
			]
		end
		
		
		if @parsed
			# retrieve parsed HTML of each revision - we need to do it for each separately
			versions.each do |v|
				resp = s.API("action=parse&oldid=#{v.revid}&prop=text&disablepp=1&format=jsonfm")
				v.text = resp['parse']['text']['*']
			end
		end
		
		
		if @revertshard
			# compare every two, starting with longest spans - if the same, mark all inbetween as reverts
			(versions.length).downto(2) do |num| # downto(2) means we also handle "edits" with no changes - like page moves
				versions.each_cons(num).with_index do |cons, i|
					if cons[0].text==cons[-1].text # we have a revert!
						cons[1...cons.length].each{|v| v.revert=true} # mark as reverts
					end
				end
			end
		elsif @reverts
			# only compare consecutive
			versions.each_cons 3 do |a, b, a_again|
				if a.text==a_again.text # we have a revert!
					b.revert=a_again.revert=true # mark as reverts
				end
			end
		end
		
		if @collapse
			versions.each_cons 2 do |pv, nv|
				if pv.user==nv.user and !pv.revert and !nv.revert # ignore reverts
					pv.deleteme=true
					nv.replace Version[
						nv.text, 
						nv.user, 
						[pv.timestamp, nv.timestamp].flatten, 
						[pv.comment, nv.comment].flatten
					]
				end
			end
			
			versions.delete_if{|v| v.deleteme}
		end
		
		
		if @colorusers
			# each user has unique color
			userslist = versions.select{|v| !v.revert}.map{|v| v.user}.uniq
			colors = get_colors userslist.length-1
			colors.unshift 'white' # for the base revision
			
			user_to_color = Hash[ userslist.zip(colors) ]

			versions.each do |v|
				if v.revert
					v.color='grey' # reverts are grey
				else
					v.color=user_to_color[v.user]
				end
			end
		else
			# each revision has unique color
			colors = get_colors(versions.count{|v| !v.revert}-1) # dont count reverts
			colors.unshift 'white' # for the base revision
		
			versions.each do |v|
				if v.revert
					v.color='grey' # reverts are grey
				else
					v.color=colors.shift
				end
			end
		end
		
		
		str=StringWithMarks.new(versions[0].text)

		(versions.length-1).times do |i|
			next if versions[i].revert # don't start from reverts
			
			j=i+1
			j+=1 until !versions[j] or !versions[j].revert # and don't finish at them
			next if !versions[j] # latest revisions were reverts
			
			d = ::Diff.diff versions[i].text, versions[j].text
			str=str.patch d, versions[j].color
		end
		
		legendhtml = 
			"Legend (#{versions.length} revisions shown):<br>\n" +
			versions.map{|v| 
				"<span style='background:#{v.color}; color:#{foreground_for v.color}'>" + 
					"#{v.user} at #{v.timestamp}, comment: #{v.comment} (#{v.color})" + 
				"</span>"
			}.join("<br>\n") # yay superfluous indentation!
		
		articlehtml = str.outputmarks
		
		css = '' # TODO
		
		return [css, legendhtml, articlehtml]
	end
end



def foreground_for color
	color =~ / (\d+)%\)/
	return 'black' if !$1 # doesn't match hsl scheme
	$1.to_i<=35 ? 'white' : 'black'
end

class Version < Array
	def text; self[0]; end
	def user; self[1]; end
	def timestamp; self[2]; end
	def comment; self[3]; end
	def color; self[4]; end
	def revert; self[5]; end
	def revid; self[6]; end
	
	def text=a; self[0]=a; end
	def user=a; self[1]=a; end
	def timestamp=a; self[2]=a; end
	def comment=a; self[3]=a; end
	def color=a; self[4]=a; end
	def revert=a; self[5]=a; end
	def revid=a; self[6]=a; end
end

class Mark < Array
	def index; self[0]; end
	def color; self[1]; end
	def length; self[2]; end
	
	def index=a; self[0]=a; end
	def color=a; self[1]=a; end
	def length=a; self[2]=a; end
end

class Object
	attr_accessor :deleteme
end

class NilClass
	def each
	end
end

class StringWithMarks < String
	attr_reader :marks

	def initialize *args
		super *args
		@marks=[]
	end

	def insertat(index, text)
		s=self[0, index]
		e=self[index, length-index]
		
		"#{s}#{text}#{e}"
	end
	
	def insertat!(index, text)
		self[0, length]=self.insertat(index, text)
	end
	
	def addmark(index, color, length)
		@marks<<Mark[index, color, length]
		return @marks.length-1
	end

	def removemark(id)
		@marks.delete(id)
	end
	
	def nudgemarks(length, index, type)
		if type==:-
			@marks.each do |m|
				if m.index>=index # m starts after removed part's start
					if m.index>index+length # m is all after removed part
						m.index-=length # so move it back
					else # m.index<=index+length - removed part ends in m
						m.length-=index+length-m.index # shorten it
						m.index=index # and nudge beginning to proper position
					end
				else # m.index<index - m starts before removed part's start
					if m.index+m.length<=index # m is all before removed part
						# do nothing
					else # m.index+m.length>index - removed part starts in m
						m.length-=length # so shorten m
					end
				end
			end
		else
			@marks.each do |m|
				if m.index>=index # added part starts after m's start
					if m.index>index+length # m is all after added part
						m.index+=length # so move it forward
					else # m.index<=index+length - added part ends in m
						m.index+=length # so move it forward
					end
				else # m.index<index - added part starts before m's start
					if m.index+m.length<=index # m is all before added part
						# do nothing
					else # m.index+m.length>index - added part starts in m
						m.length+=length # so lenghten it
					end
				end
			end
		end
		
		@marks.delete_if{|m| m[2]<1 || m[0]<0}
	end
	
	def outputmarks
		m=@marks.each_with_index{|e, i| e[3]=i} # add index info
		m=m.sort{|m1, m2| ((a=m1[0]<=>m2[0])==0 ? a=m2[2]<=>m1[2] : a) }
		addthem=[]
		
		m.reverse!
		m.each_cons 2 do |later, earlier|
			if earlier[0]+earlier[2]>later[0]
				addthem<<[ earlier[0], earlier[1], later[0]-earlier[0],              earlier[3] ]
				addthem<<[ later[0],   earlier[1], earlier[2]-(later[0]-earlier[0]), earlier[3] ]
				earlier.deleteme=true
			end
		end
		m.delete_if{|i| i.deleteme}
		m=m+addthem
		@marks=m=m.sort_by{|m| m[3]}
		
		inserts=[]
		@marks.each do |index, color, length|
			inserts[index]=[] if inserts[index]==nil
			inserts[index+length]=[] if inserts[index+length]==nil
			
			inserts[index].push "<span style='background:#{color}; color:#{foreground_for color}'>"
			inserts[index+length].send((index!=index+length ? 'unshift' : 'push'), '</span>')
		end
		
		s=self.clone
		realindex=0
		self.length.times do |fakeindex|
			inserts[fakeindex].each do |text|
				s.insertat!(realindex, text)
				realindex+=text.length
			end
			realindex+=1
		end
		
		
		# m.reverse_each do |index, color, length|
			# s.insertat!(index+length, '</span>')
			# s.insertat!(index, '<span style="background:'+color+'">')
		# end
		
		return s
	end
	
	def patch(diffs, color)
		r=self.clone
		
		adds=[]
		removes=[]
		
		diffs.each do |type, index, text|
			if type==:-
				removes<<[index, text]
			elsif type==:+
				adds<<[index, text]
			else
				raise 'Unknown diff type: '+type.to_s
			end
		end
		
		removes.reverse_each do |index, text|
			raise "Actual text not matching diff data when deleting - #{r[index, text.length]} vs #{text}" if r[index, text.length]!=text
			r[index, text.length]=''
			r.nudgemarks(text.length, index, :-)
		end
		
		adds.each do |index, text|
			r.insertat! index, text
			r.nudgemarks(text.length, index, :+)
			r.addmark index, color, text.length
		end
		
		return r
  end
end



