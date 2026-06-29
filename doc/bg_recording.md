# Background recording

This behaviour is not supported by the plugin itself.

For both Android and iOS, the recommended way is to use an external package such as [flutter_foreground_task](https://pub.dev/packages/flutter_foreground_task).

There is also a ready to use example [here](https://github.com/Dev-hwang/flutter_foreground_task_example/tree/main/record_service).

By using a dedicated package, you have much more control and this package can keep lower code surface to stay focused on recording features.

## Android

Use an external package.

## iOS

If your needs are limited, you can simply use this setup.

Add the following in `ios/Runner/info.plist`:

```xml
<key>UIBackgroundModes</key>
<array>
  <string>audio</string>
  <string>fetch</string>
</array>
```

If you use `AudioInterruptionMode.pauseResume`, you must include `IosAudioCategoryOptions.mixWithOthers` 
([stackoverflow reference](https://stackoverflow.com/questions/29036294/avaudiorecorder-not-recording-in-background-after-audio-session-interruption-end/35544795#35544795)).