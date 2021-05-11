#
# Be sure to run `pod lib lint STMURLAsset.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'STMURLAsset'
  s.version          = '0.1.0'
  s.summary          = 'STMURLAsset.'

  s.description      = <<-DESC
STMURLAsset is a subclass of AVURLAsset that can cache data downloaded by AVPlayer.
                       DESC

  s.homepage         = 'https://github.com/douking/STMURLAsset'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'DouKing' => 'wyk8916@gmail.com' }
  s.source           = { :git => 'https://github.com/douking/STMURLAsset.git', :tag => s.version.to_s }
  s.ios.deployment_target = '10.0'
  s.macos.deployment_target = '10.12'

  s.requires_arc = true
  s.swift_version = "5.0"

  s.source_files = 'Sources/STMURLAsset/**/**.swift'
  s.dependency 'Alamofire', '~> 5.4.0'
end
