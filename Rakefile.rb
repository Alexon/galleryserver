require 'active_record'
require 'yaml'
require 'uri'
require 'net/http'
require 'find'
require 'russian'

Kernel::system('chcp 1251>nul')




task :test do
  input = ENV["input"]
  p Dir[input+'/*.*']
end





#task :default => :add

def log(text)
	File.open("rakelog.txt", "a+"){|f| f.write(DateTime::now.to_s+"  "+text+"\n");}
end

desc "Task for Adding"
task :add => :environment do


	if ENV["input"]!=nil 

		class Resource < ActiveRecord::Base
		end
		
		log "#{ENV["input"]} started..."
		
		if RUBY_PLATFORM.match(/win/)
			class Resource < ActiveRecord::Base
				def haveDouble?
					Resource.exists?(:filepath=>self.filepath) or Resource.exists?(:filepath=>((File.dirname __FILE__)+"\\"+self.filepath).gsub("/","\\")) or Resource.exists?(:filepath=>"./"+self.filepath)
				end
			end
		else
			class Resource < ActiveRecord::Base
				def haveDouble?
					Resource.exists?(:filepath=>self.filepath) or Resource.exists?(:filepath=>(File.dirname __FILE__)+"/"+self.filepath) or Resource.exists?(:filepath=>"./"+self.filepath)
				end
			end
		end
	
	begin
		if(ENV["input"] =~ /^http:\/\//)
			result = loadFile(:url=>ENV["input"], :tags=>ENV["tags"], :description=>ENV["descr"])
			puts result
			log result
		else
			input = ENV["input"].gsub(/\\/, "/")
			if File.size? ENV["input"]
				accountFile input
			else
				accountDir input
			end
		end
	rescue
		puts "Error! "+$!.message
		log "Error! "+$!.message
	end
	
	log "#{ENV["input"]} processed.\r\n"
	
	else
		puts "Haven't input param!"
	end
end




def look4File f, params

	if RUBY_PLATFORM.match(/win/)
		ic = Iconv.new('UTF-8','WINDOWS-1251')
		f = ic.iconv(f)
	end

	title = File.basename f
	

	description = ENV["descr"]

	m = title.match(/(.*)(?>_| )by(?>_| )(.*)\.#{params[:ext]}/)
	if !m.nil?
		 title = m[1]
		 description = "Author: #{m[2]}" if description.nil?
	end
	

	
	res = Resource.new :filepath=>f, :title=>title, :description=>description, :mimetype=>params[:mimetype], :kind=>params[:kind], :tags=>ENV['tags'], :date=>DateTime::now()
	if res.haveDouble?
		puts "#{f} have not added: have doubles."
		return false
	end
	puts "#{f} added"
	log "#{f} added"
	res.save
end




def accountDir input
	{"jpg"=>"image/jpeg", "gif"=>"image/gif", "png"=>"image/png"}.each do |ext, mt|
		r = Dir[input+'/*.'+ext]
		kind = mt.gsub(/^([a-z]*)\/.*/, '\1')    #for example: 'image' from 'image/jpeg'
		r.each do |f|
			next unless File.size? f
			look4File f, :ext=>ext, :mimetype=>mt, :kind=>kind
		end
	end
end



$infoHash = {"jpg"=>"image/jpeg", "gif"=>"image/gif", "png"=>"image/png"}

def loadFile ( params )
   fileInfo = {}
   
   def fileInfo.filename
		raise "Have not extension" if self[:ext].nil?
		raise "Have not title" if self[:title].nil?
		#fn = self[:title]+"."+self[:ext]
		#if RUBY_PLATFORM.match(/win/)
		#	ic = Iconv.new('WINDOWS-1251','UTF-8')
		#	fn = ic.iconv(fn)
		#end
		require "digest"
		fn = Digest::MD5.hexdigest(DateTime::now().to_s) + "." + self[:ext]
		fn
   end
   
   def fileInfo.path
		"static/resources/"+self.filename
   end
   s = ""
    begin
		begin
			url = URI.parse(params[:url])
		rescue 
			url = URI.parse(URI.encode params[:url])
		end
	 s = (File.basename URI.decode url.path).gsub(/[\?\*\|<>\\\/\:]/, "")
	 matches = s.split(/.([a-zA-Z0-9]{3,4})$/)
	 s = matches
	 if matches.length>1
		fileInfo[:title] = params[:defaultTitle].nil? ? matches[0] : params[:defaultTitle]
		fileInfo[:ext] = matches[1]
	 else
		fileInfo[:title] = s
		fileInfo[:ext] = nil
	 end
	 

	 
   rescue 
     return "Parsing error: "+$!.message
   end
   

   
   request = Net::HTTP::Get.new(url.path)
	
  begin
    res = Net::HTTP.start(url.host, url.port) {|http|
     resp = http.get(url.path, "User-Agent" => "Mozilla/5.0 (Windows; U; Windows NT 6.0; ru; rv:1.9.0.10) Gecko/2009042316 Firefox/3.0.10")

	 raise "not found" if resp.code=="404"
	 fileInfo[:mime] = resp.content_type
	 	 if fileInfo[:ext].nil?
		fileInfo[:ext] = case fileInfo[:mime]
		 when "image/jpeg" then "jpg"
		 when "image/gif" then "gif"
		 when "image/png" then "png"
		 when "text/html" then "html"
		 else "txt"
		end
	 end
     raise 'file yet exists; try load with param `dTitle`' if File.exists?(fileInfo.path)
	 fileInfo[:type] = fileInfo[:mime].gsub(/([\w]+)\/(.*)/, '\1')
     open(fileInfo.path, "wb") { |file|
     file.write(resp.body)
	 file.close
    }
   }
   rescue 
        return 'Socket error: '+$!.message
end
   


	  
	
def addResource (params)
		r = Resource.new do |r|
		 r.kind = params[:type] unless params[:type].nil?
		 r.mimetype = params[:mime] unless params[:mime].nil?
		 r.sourceURL = params[:url] unless params[:url].nil?
		 if RUBY_PLATFORM.match(/win/) and !params[:path].nil?
			ic = Iconv.new('UTF-8','WINDOWS-1251')
			r.filepath = ic.iconv(params[:path])
		 end
		 r.title = params[:title] unless params[:title].nil?
		 r.tags = params[:tags] unless params[:tags].nil?
		 r.date = DateTime::now()
		end
		r.save
		return r.id
end
	
	id = addResource :type=>fileInfo[:type], :mime=>fileInfo[:mime], :url=>params[:url], :path=>fileInfo.path, :title=>fileInfo[:title], :tags=>params[:tags], :description=>params[:description]

	return  "saved as ##{id}"

end


def accountFile input
	ext = File.extname(input).gsub(".", "")
	puts ext
	
	mimetype = $infoHash[ext]
	if mimetype.nil?
		mimetype = "text/plain" 
		kind = "text"
	else
		kind = mimetype.gsub(/^([a-z]*)\/.*/, '\1')
	end
	
	look4File input, :ext=>ext, :mimetype=>mimetype, :kind=>kind
end










  
task :default => :migrate

desc "Migrate the database through scripts in db/migrate. Target specific version with VERSION=x"
task :migrate => :environment do
  ActiveRecord::Migrator.migrate('db/migrate', ENV["VERSION"] ? ENV["VERSION"].to_i : nil )
end

task :environment do
  ActiveRecord::Base.establish_connection(YAML::load(File.open('config.yml')))
  ActiveRecord::Base.logger = Logger.new(File.open('database.log', 'a'))
end

