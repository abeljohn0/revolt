Revolt Charging

<p>
 Built using Swift, UIKit, and Firebase, this project is a prototype for a social network connecting EV drivers with privately owned chargers. Essentially, an "AirBNB for EV Charging"
</p>

## User Types

- Driver: Pan around the map to find available chargers offered in your area, and select to book a charge for your car!
- Homeowner: Once you input address and charger, your offering is listed on the map, from which point drivers can book charges and you decide whether to approve or deny them!

## How to run a demo app

1. Clone the repo
2. Download the GoogleService-Info.plist file from your <a href="https://console.firebase.google.com">Firebase Console</a> and replace the existing file in the folder. This will connect the app to your own Firebase instance.
3. Install the necessary pods by running

```
pod install
```

4. Open the xcworkspace file with the latest version of Xcode
5. If this is your first time developing in Swift, be sure to also create a personal signing certificate to run the app for yourself. Do this in the project settings -> "Signing and Capabilities"

Lastly, shoutout to iosdevted and his uber-clone, which served as a piggyback prototype for our project and made for a useful starting point in our efforts!
