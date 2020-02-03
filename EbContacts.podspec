Pod::Spec.new do |s|

  s.name                = "EbContacts"
  s.version             = "0.0.2"
  s.summary             = "Contact Importer"
  s.description         = "Get all contacts from devices efficiently"
  s.homepage            = "http://ebpearls.com"
  s.license             = "Ebpearls"
  s.author              = "Ankit Karna"
  s.platform            = :ios, "11.0"
  s.source              = { :git => "https://github.com/Ankitkarna/EbContacts.git", :tag => "#{s.version}" }
  s.source_files        = "EbContacts"
  s.swift_version       = "5.0"

end
