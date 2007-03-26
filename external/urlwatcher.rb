require "md5"
require "thread"
require "servicestate"
require "../fetchlib"

# This class will watch a directory or a set of directories and alert you of
# new files, modified files, deleted files. You can optionally only be alerted
# when a files md5 hash has been changed so you only are alerted to real changes.
# this of course means slower performance and higher cpu/io usage.
class UrlWatcher
  include ServiceState

  CREATED = 0
  DELETED = 1

  # the time to wait before checking the directories again
  attr_accessor :sleepTime, :priority

  # you can optionally use the file contents md5 to detect if a file has changed
  def initialize(dir=nil, expression=".*")
    @sleepTime = 5
    @priority = 0
    @stopWhen = nil

    @directories = Array.new()
    @files = Array.new()

    @foundFiles = nil
    @firstLoad = true
    @watchThread = nil
    
    initializeState()

    if dir then
      addDirectory(dir, expression)
    end
  end

  def add(path, exp="**/*")
      if path =~ /\/$/
          addDirectory(path,exp)
      else
          addFile(path)
      end
  end

  def remove(path)
      if FileTest.directory?(path)
          removeDirectory(path)
      else
          removeDirectory(path)
      end
  end

  def clear
      @directories.clear
      @files.clear
  end

  # add a directory to be watched
  # @param dir the directory to watch
  def addDirectory(dir, expression=".*")
      @directories << URLWatcher::Directory.new(dir, expression)
  end

  def removeDirectory(dir)
    @directories.delete(dir)
  end

  # add a specific file to the watch list
  # @param file the file to watch
  def addFile(file)
      @files << file
  end

  def removeFile(file)
    @files.delete(file)
  end

  # start watching the specified files/directories
  def start(&block)
    if isStarted? then
      raise RuntimeError, "already started"
    end

    setState(STARTED)

    @firstLoad = true
    @foundFiles = Hash.new()

    # we watch in a new thread
    @watchThread = Thread.new {
      # we will be stopped if someone calls stop or if someone set a stopWhen that becomes true
      while !isStopped? do
        if (!@directories.empty?) or (!@files.empty?) then        
          # this will hold the list of the files we looked at this iteration
          # allows us to not look at the same file again and also to compare
          # with the foundFile list to see if something was deleted
          alreadyExamined = Hash.new()
          
          # check the files in each watched directory
          if not @directories.empty? then
            @directories.each { |dirObj|
              examineFileList(dirObj.getFiles(), alreadyExamined, &block)
            }
          end
          
          # now examine any files the user wants to specifically watch
          examineFileList(@files, alreadyExamined, &block) if not @files.empty?
          
          # see if we have to delete files from our found list
          if not @firstLoad then
            if not @foundFiles.empty? then
              # now diff the found files and the examined files to see if
              # something has been deleted
              allFoundFiles = @foundFiles.keys()
              allExaminedFiles = alreadyExamined.keys()
              intersection = allFoundFiles - allExaminedFiles
              intersection.each { |fileName|
                # callback
                block.call(DELETED, fileName)
                # remove deleted file from the foundFiles list
                @foundFiles.delete(fileName)
              }          
            end
          else
            @firstLoad = false
          end
        end
        
        # go to sleep
        sleep(@sleepTime)
      end
    }
    
    # set the watch thread priority
    @watchThread.priority = @priority

  end

  # kill the filewatcher thread
  def stop()
    setState(STOPPED)
    @watchThread.wakeup()
  end

  # wait for the filewatcher to finish
  def join()
    @watchThread.join() if @watchThread
  end


  private

  # loops over the file list check for new or modified files
  def examineFileList(fileList, alreadyExamined, &block)
    fileList.each { |fileName|
      # dont examine the same file 2 times
      if not alreadyExamined.has_key?(fileName) then
          # set that we have seen this file
          alreadyExamined[fileName] = true
          
          # on the first iteration just load all of the files into the foundList
          if @firstLoad then
            @foundFiles[fileName] = URLWatcher::FoundFile.new(fileName,false)
          else
            # see if we have found this file already
            foundFile = @foundFiles[fileName]

            if foundFile then
              if foundFile.isNew? then
                  block.call(CREATED, fileName)
              end
            else
              # this is a new file for our list.
              @foundFiles[fileName] = URLWatcher::FoundFile.new(fileName)
              block.call(CREATED, fileName)
            end
          end
      end
    }
  end
end

# Util classes for the UrlWatcher
module URLWatcher
  # The directory to watch
  class Directory
    attr_reader :dir, :expression

    def initialize(url, expression)
      @url, @expression = url, expression

      @machine,@port,@dir = '',80,'/'
      if url =~ /^http:\/\/([^\/]+)(\/.*)$/
          src,@dir = $1,$2
          if src =~ /^([^:]+):([0-9]+)/
              @machine = $1
              @port = $2.to_i
          else
              @machine = src
              @port = 80
          end
      end
    end

    def getFiles()
        @cmd = Fetchlib::Controller.new(@machine, @port, @dir) 
        files = @cmd.getbuf 
        return files.grep(@expression)
    end
  end

  # A FoundFile entry for the UrlWatcher
  class FoundFile
    attr_reader :status, :fileName, :modTime, :size, :md5

    def initialize(fileName, isNewFile=true)
      @fileName,@isNewFile  = fileName, isNewFile      
    end

    def isNew?
      return @isNewFile
    end
  end
end

#--- main program ----
if __FILE__ == $0
  watcher = UrlWatcher.new()
  watcher.addDirectory("http://akasham:10080/mexico/", "*.txt")
  watcher.sleepTime = 3

  test = false
  watcher.stopWhen {
    test == true
  }

  watcher.start() { |status,file|
    if status == UrlWatcher::CREATED then
      puts "created: #{file}"
    elsif status == UrlWatcher::DELETED then
      puts "deleted: #{file}"
    end
  }

  sleep(100)
  test = true
  watcher.join()
end
