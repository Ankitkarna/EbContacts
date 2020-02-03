Pod::Spec.new do |s|

  s.name                = "EbContacts"
  s.version             = "0.0.1"
  s.summary             = "Contact Importer"
  s.description         = "Get all contacts from devices efficiently"
  s.homepage            = "http://ebpearls.com"
  s.license             = "Ebpearls"
  s.author              = "Ankit Karna"
  s.platform            = :ios, "11.0"
  s.source              = { :git => "http://bitbucket.org/daemonankit/contactimporter.git", :tag => "0.0.1" }
  s.source_files        = "EbContacts"
  s.swift_version       = "5.0"

end
