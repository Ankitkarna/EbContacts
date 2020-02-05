Pod::Spec.new do |s|

  s.name                = "EbContacts"
  s.version             = "0.0.3"
  s.summary             = "Contact Importer"
  s.description         = "Get all contacts from devices efficiently"
  s.homepage            = "http://ebpearls.com"
  s.license             = "Ebpearls"
  s.author              = "Ankit Karna"
  s.platform            = :ios, "11.0"
  s.source       = { :path => '.' }
  s.source_files        = "EbContacts"
  s.swift_version       = "5.0"
  s.resources           = "EbContacts/BaxtaContactFramework.xcdatamodeld", "EbContacts/CallingCodes.plist"

end