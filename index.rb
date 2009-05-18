require 'rubygems'
require 'sinatra'
require 'mysql'
require 'activerecord'
require 'yaml'
require 'net/http'
require 'exifr'




set :root, File.dirname(__FILE__)

#set :static, true
#set :public, Proc.new { File.join(root, "static") }

set :public, File.dirname(__FILE__) + '/static'
#static '/static', 'static'
set :views, File.dirname(__FILE__) + '/views'


 
dbconfig = YAML::load(File.open(File.dirname(__FILE__)+'/database.yml'))

ActiveRecord::Base.establish_connection(dbconfig)

class Resource < ActiveRecord::Base 
end

#r = Resource.new(:title => "test")

#$f = r.inspect



class Error
	@title = "Error"
	def initialize(params)
		@text = params[:text]
		@title = params[:title]
	end
	attr_accessor :text, :title
end

$error = Error.new({})



def errorPage(param)
	headers['Content-type'] = 'text/html';
	$error = Error.new(param)
	erb :error
end



func = proc{|x,y| x + y }

def tag(params)
  "<#{params[:tagName]}>#{params[:content]}</#{params[:tagName]}>"
end


def getPath(title)
    return title if title.length<3
    return "#{title[0].chr}/#{title[1].chr}/"+title[2..-1]
end





get '/' do
  headers['Content-type'] = 'text/html';
  erb :index
  #'<i>111</i>'
end


get '/test/:test' do
  getPath params[:test]
end

get '/testbd' do
  "test user num: "+User.all(:conditions => "name regexp 't'")[0].id.to_s
end



get '/load' do
  
 if params[:url]==nil
    '<form method="get" action="/load"><input type="text" name="url" /></form>' 
 else 



   require 'uri'
   
   fileInfo = {}
   def fileInfo.filename
		raise 'Have not file extension!' if self[:ext].nil?
		raise 'Have not file title!' if self[:title].nil?
		self[:title]+"."+self[:ext]
   end
   
   def fileInfo.path
		File.dirname(__FILE__)+"/static/resources/"+self.filename
   end
   
      
   begin 
	 url = URI.parse(params[:url]) 
	 matches = url.path.split(/([a-zA-Z0-9]+).([a-zA-Z0-9]+)$/)
	 raise 'Uncorrect uri: have not file name!' if matches.length<3
	 fileInfo[:title] = matches[1]
	 fileInfo[:ext] = matches[2]
   rescue 
     return errorPage(:text=>$!.message, :title=>"Parsing error")
   end
   
   request = Net::HTTP::Get.new(url.path)
	
    
  begin
    res = Net::HTTP.start(url.host, url.port) {|http|
     raise "Same named file (#{fileInfo.filename}) yet exists! Try load with get parameter `defaultTitle`." if File.exists?(fileInfo.path) and params[:yes].nil?
     resp = http.get(url.path)
	 fileInfo[:mime] = resp.content_type
	 fileInfo[:type] = fileInfo[:mime].gsub(/([\w]+)\/(.*)/, '\1')
	 raise "Error type of resourse!<br />Mime-type: #{fileInfo[:mime]}<br />Requested type: #{params[:type]}" if !params[:type].nil? and params[:type] != fileInfo[:type]
     open(fileInfo.path, "wb") { |file|
     file.write(resp.body)
    }
   }
   rescue 
        return errorPage(:text=>$!.message, :title=>"Socket error")
   end
   
   #а вот это надо вынести потом в addResource
#=begin
	
	def addResource (params)
	#Resource(id: integer, type: string, sourceURL: string, filepath: string, mimetype: string, tags: string, description: string, date: datetime, title: string)
		r = Resource.new do |r|
		 r.type = params[:type] unless params[:type].nil?
		 r.mimetype = params[:mime] unless params[:mime].nil?
		 r.sourceURL = params[:url] unless params[:url].nil?
		 r.filepath = params[:path] unless params[:path].nil?
		 r.title = params[:title] unless params[:title].nil?
		end
		r.save
		return r.id
	end
	
	id = addResource :type=>fileInfo[:type], :mime=>fileInfo[:mime], :url=>params[:url], :path=>fileInfo.path, :title=>fileInfo[:title]

	redirect "res/#{id}"
   
	
  end
end


get '/res/:id' do
#здесь выводим страницу ресурса: картинки или...
	params[:id]
end



get '/test1' do
  '<html>
<body>
<img src="http://localhost:4567/files/guile_of_the_broken_by_drak.jpg" exif="true" id="MyPrettyImage">
<script src="http://www.nihilogic.dk/labs/exif/exif.js"></script>
<script src="http://www.nihilogic.dk/labs/binaryajax/binaryajax.js"></script>
<script>
  document.getElementById("MyPrettyImage").onclick = function() {
	alert(EXIF.pretty(this));
}

 // or use the EXIF.pretty() function to put all tags in one string, one tag per line.  
</script>
</body>
</html>'
end

get '/test' do
    #'test: '+EXIFR::JPEG.new(File.dirname(__FILE__)+'/static/files/4e77adb5aeab.jpg').software
    #header['Content-type'] = 'text/plain';
	res = ""
	obj = EXIFR::JPEG.new(File.dirname(__FILE__)+'/static/files/guile_of_the_broken_by_drak.jpg')
    obj.instance_variables.each{|m| res = res+"<br />"+m+"="+(obj.instance_variable_get(m).inspect)}
	res
	obj.inspect
	
	#open("test.jpg", "wb") { |file|
    #file.write(obj.jpeg_thumbnails)
   #}
   
end


#get %r{/([\w]+)} do
#  params[:captures][0]
#end


