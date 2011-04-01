# here we are re-opening the ruby Hash class,
# the namespace must not be specified

class Hash

  def symbolize
    self.inject({}){|out,(k,v)| out[(k.class.eql? String) ? k.to_sym : k] = v; out}
  end

end