#
# This is an extension to Singleton
# it implements a method missing to avoid having to call Class.instance.method
# we can call directly Class.method
#

module FlatSingleton

  # catch the call to the method on the class
  # and forward it to the instance of the singleton
  def method_missing(method, *args, &block)
    self.instance.send(method, *args)
  end

end