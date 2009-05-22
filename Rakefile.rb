require 'active_record'
require 'yaml'
require 'uri'
require 'net/http'
require 'find'

Kernel::system('chcp 1251>nul')

#Encoding.default_external = Encoding.find(Encoding.locale_charmap)
#Encoding.default_internal = __ENCODING__


task :default => :migrate

desc "Migrate the database through scripts in db/migrate. Target specific version with VERSION=x"
task :migrate => :environment do
  ActiveRecord::Migrator.migrate('db/migrate', ENV["VERSION"] ? ENV["VERSION"].to_i : nil )
end

task :environment do
  ActiveRecord::Base.establish_connection(YAML::load(File.open('config.yml')))
  ActiveRecord::Base.logger = Logger.new(File.open('database.log', 'a'))
end


#task :default => :tsto

desc "TSTO x!"
task :tsto do
	if ENV["test"]!=nil 
		puts "test:"+ENV["test"]
	else
		puts "Haven't param!"
	end
end




$syshash = "\\"


task :default => :add

def log(text)
	File.open("rakelog.txt", "a+"){|f| f.write(text+"\n");}
end

desc "Task for Adding"
task :add => :environment do
	if ENV["input"]!=nil 

		class Resource < ActiveRecord::Base
		end
		
		log "#{ENV["input"]} started..."
		
		if("\\"==$syshash)
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
		#если веб-файл, то обрабатываем так...
		if(ENV["input"] =~ /^http:\/\//)
			result = load(:url=>ENV["input"], :tags=>ENV["tags"], :description=>ENV["descr"])
			puts result
			log result
		else
			input = ENV["input"].gsub(/\\/, "/")
			# если файл, то обрабатываем так...
			if File.size? ENV["input"]
				accountFile input
			else
			#если папка, обрабатываем так...
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
	title = File.basename f

	description = ENV["descr"]

	m = title.match(/(.*)(?>_| )by(?>_| )(.*)\.#{params[:ext]}/)
	if !m.nil?
		 title = m[1]
		 description = "Author: #{m[2]}" if description.nil?
	end
	
	
	res = Resource.new :filepath=>f, :title=>title, :description=>description, :mimetype=>params[:mimetype], :kind=>params[:kind], :tags=>ENV['tags'], :date=>DateTime::now()
	return false if res.haveDouble?
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



def load ( params )

   
   fileInfo = {}
   def fileInfo.filename
		raise "Have not extension" if self[:ext].nil?
		raise "Have not title" if self[:title].nil?
		self[:title]+"."+self[:ext]
   end
   
   def fileInfo.path
		"static/resources/"+self.filename
   end
   
   
   begin 
	 url = URI.parse(params[:url])
	 matches = (File.basename url.path).split(/([a-zA-Z0-9]+).([a-zA-Z0-9]+)$/)
	 raise "it is not file name" if matches.length<3
	 fileInfo[:title] = ENV["defaultTitle"].nil? ? matches[1] : ENV["dTitle"]
	 fileInfo[:ext] = matches[2]
   rescue 
     return "Parsing error: "+$!.message
   end
   
   
   request = Net::HTTP::Get.new(url.path)
	
    t=""
  begin
    res = Net::HTTP.start(url.host, url.port) {|http|
     raise 'file yet exists; try load with param `dTitle`' if File.exists?(fileInfo.path)
     resp = http.get(url.path, "User-Agent" => "Mozilla/5.0 (Windows; U; Windows NT 6.0; ru; rv:1.9.0.10) Gecko/2009042316 Firefox/3.0.10")

	 raise "not found" if resp.code=="404"
	 fileInfo[:mime] = resp.content_type
	 fileInfo[:type] = fileInfo[:mime].gsub(/([\w]+)\/(.*)/, '\1')
     open(fileInfo.path, "wb") { |file|
     file.write(resp.body)
    }
   }
   rescue 
        return 'Socket error: '+$!.message
   end
   
      

	  
	
	def addResource (params)
	#Resource(id: integer, type: string, sourceURL: string, filepath: string, mimetype: string, tags: string, description: string, date: datetime, title: string)
		r = Resource.new do |r|
		 r.kind = params[:type] unless params[:type].nil?
		 r.mimetype = params[:mime] unless params[:mime].nil?
		 r.sourceURL = params[:url] unless params[:url].nil?
		 r.filepath = params[:path] unless params[:path].nil?
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





