require 'rubygems'
require 'sinatra'
require 'mysql'
require 'activerecord'
require 'yaml'
require 'net/http'


=begin
#simple authorization
use Rack::Auth::Basic do |username, password|
username == 'admin' && password == 'secre'
end
=end



=begin
#EXIF example
    #<EXIFR::JPEG:0x40ef390 
    @width=800, 
    @height=1007, 
    @bits=8, 
    @exif=[
      {
      :software=>"Adobe Photoshop CS3 Windows", 
      :date_time=>Tue Mar 11 21:46:41 +0300 2008, 
      :orientation=>#<EXIFR::TIFF:
        :Orientation:0x34d05a0 
        @type=:TopLeft, 
        @value=1>, 
        :color_space=>65535, 
        :x_resolution=>Rational(300, 1), 
        :pixel_x_dimension=>800, 
        :y_resolution=>Rational(300, 1), 
        :resolution_unit=>2, 
        :pixel_y_dimension=>1007
        },
         {
          :jpeg_interchange_format=>302, 
          :jpeg_interchange_format_length=>4546, 
          :compression=>6, 
          :x_resolution=>Rational(72, 1), 
          :y_resolution=>Rational(72, 1), 
          :resolution_unit=>2
         }
        ]>
=end


#Тут будут всякие полезные сэмплы


#set :public, File.dirname(__FILE__) + '/static'
#static '/static', 'static'
set :views, File.dirname(__FILE__) + '/views'


 
dbconfig = YAML::load(File.open('database.yml'))
ActiveRecord::Base.establish_connection(dbconfig)

class User < ActiveRecord::Base 
end


#u = User.new(:name=>'SPARTAA!!!');
#u.save;

#u = User.all(:conditions => "name regexp 't'")[0]

#User.delete(1);


#u = User.new(:name=>'SPARTAA!!!');
#u.save;


#users = User.all(:conditions => "name regexp '!'")
#users.map{|user| User.delete(user.id)}


u = User.first(:select => 'name')



test = 'test test test'

func = proc{|x,y| x + y }

def tag(params)
  "<#{params[:tagName]}>#{params[:content]}</#{params[:tagName]}>"
end

get '/' do
  header['Content-type'] = 'text/html';
  erb :index
  #'<i>111</i>'
end

get '/load' do
=begin
  Net::HTTP.start("ya.ru") { |http|
  resp = http.get("/logo.png")
  open("fun.png", "wb") { |file|
    file.write(resp.body)
   }
  }
  
=end
  '<form method="get" action="/load/1"><input type="text" value="test11111" name="t" /></form>'
end

get '/load/1' do
 params[:t]
end


#test static pages
#get '/static/test.txt' do
#end



get %r{/([\w]+)} do
  params[:captures][0]
end


get '/load' do

=begin
  Net::HTTP.start("ya.ru") { |http|
  resp = http.get("/logo.png")
  open("static/resources/fun.png", "wb") { |file|
    file.write(resp.body)
   }
  }
  return "1"
=end
  
 if params[:url]==nil
    '<form method="get" action="/load"><input type="text" name="url" /></form>' 
 else 
=begin
    result = ""
    i = 0
    matches = params[:url].split(/(http:\/\/)?([^\/]*)(\/(.*?)([^\/]+))?$/)
    for m in matches do
      result = result +"[#{i}]="+m+ "<br />"
      i += 1
   end
   
   #return result
   return errorPage(:text=>"Error URL: \"#{params[:url]}\" is no image resource", :title=>'Not found') if matches.length<3
   
   result  # или всё-таки по умолчанию писать в файл с рандомной нотацией, опознавая тип файла по mime-type?
   domain = matches[1]=="http://" ? matches[2] : matches[1]
   resourceName = matches[2]==nil ? "/" : matches[2]
   #title = matches.last=~/\// ? (params[:defaultTitle]==nil ? nil : params[:defaultTitle]) : matches.last
   title =  params[:defaultTitle]==nil ? (matches.last=~/\// ? nil : matches.last) : params[:defaultTitle]
   return errorPage(:text=>"Error URL: \"#{params[:url]}\" not contains file title.", :title=>'Not found') if title.nil?

=end


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
	
    
t = ""
  begin
    res = Net::HTTP.start(url.host, url.port) {|http|
     #raise "Same named file (#{fileInfo.filename}) yet exists! Try load with get parameter `defaultTitle`." if File.exists?(fileInfo.path)
     resp = http.get(url.path)
	 fileInfo[:mime] = resp.content_type
	 fileInfo[:type] = fileInfo[:mime].gsub(/([\w]+)\/(.*)/, '\1')
	 raise "Error type of resourse!<br />Mime-type: #{fileInfo[:mime]}<br />Requested type: #{params[:type]}" if !params[:type].nil? and params[:type] != fileInfo[:type]
	 #t = fileInfo[:type]
     open(fileInfo.path, "wb") { |file|
     file.write(resp.body)
    }
   }
   rescue 
        return errorPage(:text=>$!.message, :title=>"Socket error")
   end
   
   #а вот это надо вынести потом в addResource
#=begin
   r = Resource.new(:type=>fileInfo[:type], 
					:mimetype=>fileInfo[:mime], 
					:sourceURL=>params[:url], 
					:filepath=>fileInfo.path,
					:title=>fileInfo[:title]);
#=end

#Resource(id: integer, type: string, sourceURL: string, filepath: string, mimetype: string, tags: string, description: string, date: datetime, title: string)
	return r.inspect
   
#u.save;
   #return t
   
#return fileInfo.path

  #"result="+result+"<br />"+"domain="+domain+"<br />"+"title="+title+"<br />"+"resourceName="+resourceName
  #matches.inspect
	
  end
end