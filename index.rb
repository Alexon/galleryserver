require 'rubygems'
require 'sinatra'
require 'sinatra/r18n'
require 'mysql'
require 'activerecord'
require 'yaml'
require 'net/http'
require 'exifr'
require 'RMagick'




set :root, File.dirname(__FILE__)



set :public, File.dirname(__FILE__) + '/static'

set :views, File.dirname(__FILE__) + '/views'


 
$config = YAML::load(File.open(File.dirname(__FILE__)+'/config.yml'))

ActiveRecord::Base.establish_connection($config)

class Resource < ActiveRecord::Base 
	def tags2HTML
		return "--" if self.tags.nil?
		self.tags+"_test"
		self.tags.split(",").map{|s| "<a href='/tag/#{s}'>#{s}</a>"}.join(", ")
	end
	
	def imgHTML
		return "<img src='/res/img/#{self.id}' id='image' exif='true' />"
	end
	
	def exif?
		begin
			obj = EXIFR::JPEG.new(self.filepath)
		rescue 
			return false
		end
		return !obj.nil?
	end
	
	def image?
		return "image"==self.kind
	end
	
	def previewHTML
		return "<a href='/res/img/#{self.id}/full'><img src='/res/img/#{self.id}/preview/#{$config["thumbsize"]}' /></a>" if self.image?
		"test"
	end
	
	def outerHelper(field)
		"<div id='#{field}_container' title='Title'>"+eval("self.#{field}_helper")+"</div>"
	end
	
	def title_helper
		"<span class='con'>#{self.title}</span>"
	end
	
	def id_helper
		"<span class='big'>ID</span>: <a href='/res/#{self.id}'>##{self.id}</a>"
	end
	
	def description_helper
		"<span class='big'>#{t("res.Description")}</span>: 
			#{(self.description.nil? or self.description.length==0) ? t("res.Hvc")+"<span class='con'></span>" : "<span class='con'>"+self.description+"</span>"}"
	end
	
	def sourceURL_helper
		"<span class='big'>#{t("res.Source")}</span>: 
			#{(self.sourceURL.nil? or self.sourceURL.length==0) ? t("res.Hvsour")+"<span class='con'></span>" : "<a href='#{self.sourceURL}'><span class='con'>#{self.sourceURL}</span></a>"}"
	end
	
	def tags_helper
		"<span class='big'>#{t("res.Tags")}</span>: 
			#{self.tags2HTML}
			<span class='con' style='display:none;'>#{self.tags}</span>"
	end
	
	def filepath_helper
		"<span class='big'>#{t("res.Path")}</span>: 
			<a href='/res/img/#{self.id}/full'><span class='con'>#{self.filepath}</span></a> "
	end
	
	def getDate
		self.date.strftime("%Y-%m-%d  %H:%M:%S")
	end
	
	def date_helper
		"<span class='big'>#{t("res.Date")}</span>: 
			<span class='con'>#{self.getDate}</span>"
	end	
	
	def mimetype_helper
		"<span class='big'>#{t("res.mimetype")}</span>: 
			<span class='con'>#{self.mimetype}</span>"
	end	
	
	def kind_helper
		"<span class='big'>#{t("res.kind")}</span>:
			#{t(self.kind)}
			<span class='con' style='display:none;'>#{self.kind}</span>"
	end
	
	
	#dirty, dirty hack...
	@i18n
	def t (str)
		return eval("@i18n."+str)
	end
	
	def i18n=(value)
		@i18n = value
	end
	
	
	def deleteAttach
		File.delete(self.filepath) unless self.filepath.nil?
	end
	
	def to_tr
		"<tr><td><a href='/res/#{self.id}'>##{self.id}</a></td> <td>#{self.previewHTML}</td> <td><a href='/res/#{self.id}'>#{self.title}</a></td> <td>#{self.tags2HTML}</td> <td>#{self.getDate}</td></tr>\n"
	end
end










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






get '/' do
  #params[:locale] = $config["locale"]
  index(params)
end


get %r{$/([a-z]{2,3})^} do
  params[:locale] = params["captures"][0]
  index(params)
end


def index(params)
	headers['Content-type'] = 'text/html;charset=UTF-8';
	
	$count = Resource.count
	$max = ($count/$config["indexLimit"].to_f).floor
	$page = params[:page].nil? ? $max : params[:page].to_i
	
	$res = Resource.find :all, :order => "id ASC", :limit => $config["indexLimit"], :offset => $page*$config["indexLimit"].to_i, :order => :id
	erb :index
end



get '/load/:locale' do
	load(params)
end

get '/load/?' do
	#params[:locale] = $config["locale"]
	load(params)
end


def load(params)
  
  header['Content-type'] = 'text/html;charset=UTF-8';
  
 if params[:url]==nil
	erb :load
 else 


 
   require 'uri'
   
   fileInfo = {}
   def fileInfo.filename
		raise i18n.errors.notHaveExt if self[:ext].nil?
		raise i18n.errors.notHaveTitle if self[:title].nil?
		self[:title]+"."+self[:ext]
   end
   
   def fileInfo.path
		"static/resources/"+self.filename
   end
   
   
   begin 
	 url = URI.parse(params[:url])
	 #matches = url.path.split(/([a-zA-Z0-9]+).([a-zA-Z0-9]+)$/)
	 matches = (File.basename url.path).split(/([a-zA-Z0-9]+).([a-zA-Z0-9]+)$/)
	 raise i18n.errors.notFileName if matches.length<3
	 fileInfo[:title] = params[:defaultTitle].nil? ? matches[1] : params[:defaultTitle]
	 fileInfo[:ext] = matches[2]
   rescue 
     return errorPage(:text=>$!.message, :title=>i18n.errors.title.parsing)
   end
   
   
   request = Net::HTTP::Get.new(url.path)
	
    t=""
  begin
    res = Net::HTTP.start(url.host, url.port) {|http|
     raise i18n.errors.yetExists(fileInfo.filename) + "<br /> <form action='/load' method='get'><input type='hidden' name='url' value='#{params[:url]}' /><input type='text' value='#{fileInfo[:title]}_' name='defaultTitle' /><input type='submit' value='go' /></form>" if File.exists?(fileInfo.path) and params[:yes].nil?
     resp = http.get(url.path, "User-Agent" => "Mozilla/5.0 (Windows; U; Windows NT 6.0; ru; rv:1.9.0.10) Gecko/2009042316 Firefox/3.0.10")

	 raise i18n.errors.notFound if resp.code=="404"
	 fileInfo[:mime] = resp.content_type
	 fileInfo[:type] = fileInfo[:mime].gsub(/([\w]+)\/(.*)/, '\1')
	 raise i18n.errors.errorType(fileInfo[:mime], params[:type]) if !params[:type].nil? and params[:type] != fileInfo[:type]
     open(fileInfo.path, "wb") { |file|
     file.write(resp.body)
    }
   }
   rescue 
        return errorPage(:text=>$!.message, :title=>i18n.errors.title.socket)
   end
   
      

	  
	
	def addResource (params)
	#Resource(id: integer, type: string, sourceURL: string, filepath: string, mimetype: string, tags: string, description: string, date: datetime, title: string)
		r = Resource.new do |r|
		 r.kind = params[:type] unless params[:type].nil?
		 r.mimetype = params[:mime] unless params[:mime].nil?
		 r.sourceURL = params[:url] unless params[:url].nil?
		 r.filepath = params[:path] unless params[:path].nil?
		 r.title = params[:title] unless params[:title].nil?
		 r.date = DateTime::now()
		end
		r.save
		return r.id
	end
	
	id = addResource :type=>fileInfo[:type], :mime=>fileInfo[:mime], :url=>params[:url], :path=>fileInfo.path, :title=>fileInfo[:title]

	redirect "/res/#{id}/#{params[:locale]}"
   
	
  end
end



get '/res/img/:id/full' do
	begin
		$r = Resource.find(params[:id])
	rescue
		return errorPage(:text=>$!.message, :title=>"Resource ##{params[:id]} not found")
	end
	
	header['Content-type'] = $r.mimetype
		
	begin
		File.open($r.filepath).binmode.read
	rescue
		notFoundImage
	end
end



get '/res/img/:id' do
	begin
		$r = Resource.find(params[:id])
	rescue
		return errorPage(:text=>$!.message, :title=>"Resource ##{params[:id]} not found")
	end
	
	header['Content-type'] = $r.mimetype
		
	begin
			maxwidth = $config["maxwidth"]
			maxheight = $config["maxheight"]
			aspectratio = maxwidth.to_f / maxheight.to_f
		
			img = Magick::Image.read($r.filepath).first
			imgwidth = img.columns
			imgheight = img.rows
			
			if imgwidth>maxwidth or imgheight>maxheight		
				imgratio = imgwidth.to_f / imgheight.to_f
				imgratio > aspectratio ? scaleratio = maxwidth.to_f / imgwidth : scaleratio = maxheight.to_f / imgheight
				img.resize!(scaleratio)
			end
			
			return img.to_blob
	rescue
		notFoundImage
	end
end


get '/res/img/:id/preview/:size' do
	begin
		$r = Resource.find(params[:id])
	rescue
		return errorPage(:text=>$!.message, :title=>"Resource ##{params[:id]} not found")
	end
	
	begin
			header['Content-type'] = $r.mimetype
			img = Magick::Image.read($r.filepath).first
			max = img.columns>img.rows ? img.columns : img.rows
			scaleratio = params[:size].to_f/max
			img.resize!(scaleratio)
			return img.to_blob
	rescue
		notFoundImage
	end
end


def notFoundImage
	#redirect '/notFound.png'
	header['Content-type'] = "image/png"
	File.open('static/notFound.png').binmode.read
end






get '/res/:id/:locale' do
	res params
end



get '/res/:id' do
	#params[:locale] = $config["locale"]
	res params
end

get '/res/:id/' do
	#params[:locale] = $config["locale"]
	res params
end



def res(params)

	header['Content-type'] = 'text/html;charset=UTF-8';

	begin
		$r = Resource.find(params[:id])
		$r.i18n = i18n
		$left = Resource.exists?(params[:id].to_i-1)
		$right = Resource.exists?(params[:id].to_i+1)
	rescue
		return errorPage(:text=>$!.message, :title=>"Resource ##{params[:id]} not found")
	end
	
	
	def $r.path
		self.filepath.gsub(/static\/(.*)/, '\1')
	end

	erb :res

end


post '/edit/:id/:field' do
	#require 'cgi'
	#params["data"] = CGI.unescape(params["data"])
	edit params
end


def edit(params)
	begin
		r = Resource.find(params[:id])
	rescue
		return false
	end
	
	begin
		return "false" if params["field"]=="id" or r.column_for_attribute(params["field"]).nil?
		eval("r."+params["field"]+"=params['data']")
		r.save
		r.i18n = i18n
		return eval("r."+params["field"]+"_helper")
	rescue 
		return "false"
	end
end



get '/delete/:id' do

	begin
		r = Resource.find(params[:id])
	rescue
		return errorPage(:text=>$!.message, :title=>i18n.errors.notFound)
	end
	 return errorPage(:text=>i18n.delete.withAttachOrNo+"<br /><a href='/delete/#{params[:id]}?attach=yes'>#{i18n.__yes}</a> | <a href='/delete/#{params[:id]}?attach=no'>#{i18n.__no}</a>", :title=>i18n.errors.title.changeTypeOfDeleting) if(params[:attach].nil? or ("yes"!=params[:attach] and "no"!=params[:attach]))


	begin
		r.deleteAttach if("yes"==params[:attach])
	rescue
		nil
	end
	
	Resource.delete(params[:id])
	
	redirect '/'
end



get '/tag/:tag' do
	tagSearch params
end


get '/tag/:locale/:tag' do
	tagSearch params
end

def tagSearch(params)
	$count = Resource.count :conditions=>"tags regexp '(,|^)#{params[:tag]}(,|$)'"
	$max = ($count/$config["indexLimit"].to_f).floor
	$page = params[:page].nil? ? $max : params[:page].to_i
	
	$res = Resource.all :conditions=>"tags regexp '(,|^)#{params[:tag]}(,|$)'", :limit=>$config["indexLimit"], :offset=>$page*$config["indexLimit"].to_i
	$title = i18n.search.forTag + ": " + params[:tag];
	$header = i18n.search.forTag + ": " + "<a href='/tag/#{params[:tag]}'>#{params[:tag]}</a>";
	erb :tags
end


def pagin(page, max)
	s = ""
	(0..max).to_a.each do |n|
		if(page!=n)
			s+="<a href='?page=#{n}'>#{n}</a> "
		else
			s+="<b>#{n}</b> "
		end
	end
	s
end


















