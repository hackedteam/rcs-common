require 'base64'
require 'openssl'
require 'json'

module RCS
  module Mongoid
    module Signature
      extend ActiveSupport::Concern

      DSA_PRIV_KEY = <<END
-----BEGIN DSA PRIVATE KEY-----
MIIDVgIBAAKCAQEAs/Le9TeFwd6Wp0ZaSwthvKcYmMkewqyx3L+xl7S4EkQOI4ky
9n4Yp4LJ2EnIdo6iwj5fLcxTXRPem1uWaPNXT0ILKWr6Eu9yetgKaiK6i+Iy8Rtb
XA2e/CEh+Hl4zL5UnNLQcxtZ7pYML6Lq7h27OTyXFU4tZsxSH1oSdr0KJE7kHmij
gLaub5yjjBQF8pcADpWHih06NQ6zj7rKEXH2RLgiE3dZbN29VqP3/edx1XASuoAd
6DKzfYH8H9Pp6mMI9s2+kzvLdnubuDdq+rA3aSZC+iHczBUCjbdshLzsyac4et5b
wjRIKZmA674InCKq2MVZjJPoE1jmoPpINigo2QIhAIn55YqthSk3B044NJSL7pfg
UwrWAT00RAuKoB849MSRAoIBAGcdWSnhTjRbWV23niaLnDGH+s/v9UGcokGQiTU9
4Yy+6fVaFoNqs6s4wfcGaQDQIUDZ67dMU2ARkImLjxAN/DOnopXtwdZQXd9vXoMp
Qi89lfJ8/elwW4nAY9cWnyl67shv17vyjJZATMvH8/YvyphDJDUh191z3MGu/6O+
yRuZcJ0aqyvcbGpj0zox9oFLnNltroeB7zExeJ5GFcVrZQ5Tza07LcRBjAbo0Icw
F6bNVRadrLRywwxE+zym73Vz4x48euoKo95AsevOFQ+osIlDEL1BkPKa9jiEFTHq
XBleabczfnBYTOIwNWKuUXeboBpjNX5ZPzOu+UvnRr9JLDMCggEBAJhmfz1PDIA5
TvfUyUT9NkLUpQk5EOvQ4fAQx7ktETA683lEZR+sdL66aEheqEwMRor1DofM/gYO
WAE+tzusnPZ/yrP6mrLXeWrWbjM0gdcbW2NVR7Vh6s3fziX6UIxpmBeWitqYE4PH
ue9p6meRhHxR5HB2ws9EldxCN/sgqOvVIAhfbla0WMd1kEkSi9Zoitl43LtP2GhJ
pb+O4eBoOfdC4c3eYlHgXYAEo5CYytDF+Rv51Mu9BsqPfcPsAGgaAQLugqLYYHRw
LKzCzBPvkAF1C+zW+Qk+FrZbwhBqiJBSXH7IxM+6OrQxLR+lJuLBSkSap30TFBc7
g3zksvKZdi0CIEPlMqeN/iQIXzjDP9L8ofSkoo/x7ixyaHHk6CjmoWMm
-----END DSA PRIVATE KEY-----
END

      DSA_PUB_KEY = <<END
-----BEGIN PUBLIC KEY-----
MIIDRzCCAjkGByqGSM44BAEwggIsAoIBAQCz8t71N4XB3panRlpLC2G8pxiYyR7C
rLHcv7GXtLgSRA4jiTL2fhingsnYSch2jqLCPl8tzFNdE96bW5Zo81dPQgspavoS
73J62ApqIrqL4jLxG1tcDZ78ISH4eXjMvlSc0tBzG1nulgwvouruHbs5PJcVTi1m
zFIfWhJ2vQokTuQeaKOAtq5vnKOMFAXylwAOlYeKHTo1DrOPusoRcfZEuCITd1ls
3b1Wo/f953HVcBK6gB3oMrN9gfwf0+nqYwj2zb6TO8t2e5u4N2r6sDdpJkL6IdzM
FQKNt2yEvOzJpzh63lvCNEgpmYDrvgicIqrYxVmMk+gTWOag+kg2KCjZAiEAifnl
iq2FKTcHTjg0lIvul+BTCtYBPTREC4qgHzj0xJECggEAZx1ZKeFONFtZXbeeJouc
MYf6z+/1QZyiQZCJNT3hjL7p9VoWg2qzqzjB9wZpANAhQNnrt0xTYBGQiYuPEA38
M6eile3B1lBd329egylCLz2V8nz96XBbicBj1xafKXruyG/Xu/KMlkBMy8fz9i/K
mEMkNSHX3XPcwa7/o77JG5lwnRqrK9xsamPTOjH2gUuc2W2uh4HvMTF4nkYVxWtl
DlPNrTstxEGMBujQhzAXps1VFp2stHLDDET7PKbvdXPjHjx66gqj3kCx684VD6iw
iUMQvUGQ8pr2OIQVMepcGV5ptzN+cFhM4jA1Yq5Rd5ugGmM1flk/M675S+dGv0ks
MwOCAQYAAoIBAQCYZn89TwyAOU731MlE/TZC1KUJORDr0OHwEMe5LREwOvN5RGUf
rHS+umhIXqhMDEaK9Q6HzP4GDlgBPrc7rJz2f8qz+pqy13lq1m4zNIHXG1tjVUe1
YerN384l+lCMaZgXloramBODx7nvaepnkYR8UeRwdsLPRJXcQjf7IKjr1SAIX25W
tFjHdZBJEovWaIrZeNy7T9hoSaW/juHgaDn3QuHN3mJR4F2ABKOQmMrQxfkb+dTL
vQbKj33D7ABoGgEC7oKi2GB0cCyswswT75ABdQvs1vkJPha2W8IQaoiQUlx+yMTP
ujq0MS0fpSbiwUpEmqd9ExQXO4N85LLymXYt
-----END PUBLIC KEY-----
END

      included do
        cattr_accessor :signature_fields
        self.signature_fields = []

        cattr_accessor :signature_chained
        self.signature_chained = false

        cattr_accessor :dsa_priv, :dsa_pub
        self.dsa_priv = OpenSSL::PKey::DSA.new(DSA_PRIV_KEY)
        self.dsa_pub = OpenSSL::PKey::DSA.new(DSA_PUB_KEY)

        field :signature, type: Hash, default: {}

        set_callback :create, :before, :set_signature
        set_callback :update, :before, :set_signature
      end

      def set_signature
        now = Time.now.getutc.to_f

        # save the version and the fields used to calculate the signature
        # this could help in the future if the signature_fields are changed
        hash = {version: 1,
                fields: signature_fields,
                timestamp: now}

        #puts "SET: #{signature_fields} => #{concat_values(hash, signature_fields)}"

        # calculate the digest
        digest = OpenSSL::Digest::SHA256.digest(concat_values(hash, signature_fields))
        # sign the digest
        sig = dsa_priv.syssign(digest)

        # put the dsa signature in the hash and save it
        hash[:signature] = Base64.strict_encode64(sig)
        self.signature[:integrity] = Base64.strict_encode64(hash.to_json)
      end

      def check_signature
        # load the serialized signature
        hash = JSON.parse(Base64.decode64(self.signature[:integrity])).with_indifferent_access

        # extract and remove the dsa signature from the hash
        sig = Base64.decode64(hash.delete(:signature))

        #puts "CHECK: #{signature_fields} => #{concat_values(hash, hash[:fields])}"

        # calculate the digest
        digest = OpenSSL::Digest::SHA256.digest(concat_values(hash, hash[:fields]))
        # verify the integrity
        dsa_pub.sysverify(digest, sig)
      rescue Exception => e
        #puts e.message
        #puts e.backtrace.join("\n")
        false
      end

      def signature_fields
        self.class.signature_fields
      end

      private

      def concat_values(hash, keys)
        # always include the id of the document to prevent cloning of document
        # also include the hash itself (with timestamp) to prevent replay attack
        text = self[:_id].to_s + '|' + hash.to_json + '|'

        # concatenate all the other fields
        keys.each do |key|
          # use json serialization here, since it works for strings, integers, complex arrays or hashes...
          text << self[key].to_json + '|' unless self[key].blank?
        end

        return text
      end

      module ClassMethods
        def sign_options(options)
          self.signature_fields = options[:include] if options[:include]
        end
      end

    end
  end
end