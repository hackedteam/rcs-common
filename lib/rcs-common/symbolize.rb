# here we are re-opening the ruby Hash class,
# the namespace must not be specified

class Hash

  def symbolize
    self.inject({}){|out,(k,v)| out[k.to_sym] = v; out}
  end

end