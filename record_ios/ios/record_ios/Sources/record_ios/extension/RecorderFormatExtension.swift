import AVFoundation

extension AudioRecordingDelegate {
  func getFileTypeFromSettings(_ settings: [String: Any]) -> AVFileType {
    let formatId = settings[AVFormatIDKey] as! UInt32
    switch formatId {
    case kAudioFormatAMR, kAudioFormatAMR_WB: return .mobile3GPP
    case kAudioFormatLinearPCM:               return .wav
    default:                                  return .m4a
    }
  }

  func getInputSettings(config: RecordConfig) -> [String: Any] {
    AVAudioFormat(
      commonFormat: .pcmFormatInt16,
      sampleRate: min(Double(config.sampleRate), 48000.0),
      channels: UInt32(min(config.numChannels, 2)),
      interleaved: false
    )!.settings
  }

  // https://developer.apple.com/documentation/coreaudiotypes/coreaudiotype_constants/1572096-audio_data_format_identifiers
  func getOutputSettings(config: RecordConfig) throws -> [String: Any] {
    var settings = initialOutputSettings(config: config)
    let keepSampleRate = config.encoder == AudioEncoder.pcm16bits.rawValue
                      || config.encoder == AudioEncoder.wav.rawValue

    guard let inFormat = AVAudioFormat(settings: getInputSettings(config: config)) else {
      throw RecorderError.error(message: "Failed to start recording", details: "Input format initialization failure.")
    }
    guard let outFormat = AVAudioFormat(settings: settings) else {
      throw RecorderError.error(message: "Failed to start recording", details: "Output format initialization failure.")
    }
    guard let converter = AVAudioConverter(from: inFormat, to: outFormat) else {
      throw RecorderError.error(message: "Failed to start recording", details: "Format conversion isn't possible. Format or configuration is not supported.")
    }

    adjustSampleRate(in: &settings, converter: converter, keepSampleRate: keepSampleRate)
    adjustBitRate(in: &settings, converter: converter)
    return settings
  }
}

// MARK: - Per-encoder initial settings

private extension AudioRecordingDelegate {
  func initialOutputSettings(config: RecordConfig) -> [String: Any] {
    switch config.encoder {
    case AudioEncoder.aacLc.rawValue:  return aacSettings(formatId: kAudioFormatMPEG4AAC,        config: config)
    case AudioEncoder.aacEld.rawValue: return aacSettings(formatId: kAudioFormatMPEG4AAC_ELD_V2, config: config)
    case AudioEncoder.aacHe.rawValue:  return aacSettings(formatId: kAudioFormatMPEG4AAC_HE_V2,  config: config)
    case AudioEncoder.amrNb.rawValue:  return amrNbSettings(config: config)
    case AudioEncoder.amrWb.rawValue:  return amrWbSettings(config: config)
    case AudioEncoder.opus.rawValue:   return opusSettings(config: config)
    case AudioEncoder.flac.rawValue:   return flacSettings(config: config)
    case AudioEncoder.pcm16bits.rawValue,
         AudioEncoder.wav.rawValue:    return pcmSettings(config: config)
    default:                           return aacSettings(formatId: kAudioFormatMPEG4AAC, config: config)
    }
  }

  func aacSettings(formatId: UInt32, config: RecordConfig) -> [String: Any] {
    [
      AVFormatIDKey:            formatId,
      AVEncoderBitRateKey:      config.bitRate,
      AVSampleRateKey:          config.sampleRate,
      AVNumberOfChannelsKey:    config.numChannels,
      AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
    ]
  }

  func amrNbSettings(config: RecordConfig) -> [String: Any] {
    [
      AVFormatIDKey:               kAudioFormatAMR,
      AVEncoderBitRateKey:         config.bitRate,
      AVSampleRateKey:             8000,
      AVNumberOfChannelsKey:       config.numChannels,
      AVLinearPCMBitDepthKey:      8,
      AVLinearPCMIsFloatKey:       false,
      AVLinearPCMIsBigEndianKey:   false,
      AVLinearPCMIsNonInterleaved: true,
      AVEncoderAudioQualityKey:    AVAudioQuality.high.rawValue,
    ]
  }

  func amrWbSettings(config: RecordConfig) -> [String: Any] {
    [
      AVFormatIDKey:            kAudioFormatAMR_WB,
      AVEncoderBitRateKey:      config.bitRate,
      AVSampleRateKey:          16000,
      AVNumberOfChannelsKey:    config.numChannels,
      AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
    ]
  }

  func opusSettings(config: RecordConfig) -> [String: Any] {
    let validRates: [NSNumber] = [8000, 12000, 16000, 24000, 48000]
    return [
      AVFormatIDKey:            kAudioFormatOpus,
      AVEncoderBitRateKey:      config.bitRate,
      AVSampleRateKey:          nearestValue(to: config.sampleRate as NSNumber, in: validRates, key: "opus sample rate"),
      AVNumberOfChannelsKey:    config.numChannels,
      AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
    ]
  }

  func flacSettings(config: RecordConfig) -> [String: Any] {
    [
      AVFormatIDKey:            kAudioFormatFLAC,
      AVEncoderBitRateKey:      config.bitRate,
      AVSampleRateKey:          config.sampleRate,
      AVNumberOfChannelsKey:    config.numChannels,
      AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
    ]
  }

  func pcmSettings(config: RecordConfig) -> [String: Any] {
    [
      AVFormatIDKey:               kAudioFormatLinearPCM,
      AVLinearPCMBitDepthKey:      16,
      AVLinearPCMIsFloatKey:       false,
      AVLinearPCMIsBigEndianKey:   false,
      AVLinearPCMIsNonInterleaved: false,
      AVSampleRateKey:             config.sampleRate,
      AVNumberOfChannelsKey:       config.numChannels,
      AVEncoderAudioQualityKey:    AVAudioQuality.high.rawValue,
    ]
  }

  func adjustSampleRate(in settings: inout [String: Any], converter: AVAudioConverter, keepSampleRate: Bool) {
    if let rate = settings[AVSampleRateKey] as? NSNumber,
       let available = converter.availableEncodeSampleRates {
      settings[AVSampleRateKey] = nearestValue(to: rate, in: available, key: "sample rates").floatValue
    } else if !keepSampleRate {
      settings.removeValue(forKey: AVSampleRateKey)
    }
  }

  func adjustBitRate(in settings: inout [String: Any], converter: AVAudioConverter) {
    if let rate = settings[AVEncoderBitRateKey] as? NSNumber,
       let available = converter.availableEncodeBitRates {
      settings[AVEncoderBitRateKey] = nearestValue(to: rate, in: available, key: "bit rates").intValue
    } else {
      settings.removeValue(forKey: AVEncoderBitRateKey)
    }
  }
}

// MARK: - Utilities

private func nearestValue(to value: NSNumber, in values: [NSNumber], key: String) -> NSNumber {
  guard !values.isEmpty, !(values.count == 1 && values[0] == 0) else { return value }

  var bestIdx = 0
  var bestDist = abs(values[0].floatValue - value.floatValue)
  for i in 1..<values.count {
    let d = abs(values[i].floatValue - value.floatValue)
    if d < bestDist { bestIdx = i; bestDist = d }
  }

  if values[bestIdx] != value {
    print("Available \(key): \(values). Given \(value) adjusted to \(values[bestIdx]).")
  }
  return values[bestIdx]
}
