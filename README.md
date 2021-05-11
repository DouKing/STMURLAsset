# STMURLAsset

`STMURLAsset` is a subclass of `AVURLAsset` that can cache data downloaded by `AVPlayer`.

### Usage

Just use it like `AVURLAsset`

```swift
let url = URL(string: "http://clips.vorwaerts-gmbh.de/big_buck_bunny.mp4")!
let asset = STMURLAsset(url: url)
asset.preloadAsynchronously()
let playerItem = AVPlayerItem(asset: asset)
let player = AVPlayer(playerItem: playerItem)
let playerView = PlayerView()
playerView.playerLayer.player = player
```

### Installation

##### Swift Package Manager

- File > Swift Packages > Add Package Dependency
- Add `https://github.com/douking/STMURLAsset`
- Select "Up to Next Major" with "0.1.0"

##### Cocoapods

Add the following line to your Podfile:

```ruby
pod 'STMURLAsset'
```

### License

`STMURLAsset` is available under the MIT license. See the LICENSE file for more info.

