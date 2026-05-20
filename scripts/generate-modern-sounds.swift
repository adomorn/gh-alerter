#!/usr/bin/env swift

import Foundation

let sampleRate = 44_100
let outputDirectory = URL(fileURLWithPath: "Sources/GHAlerterApp/Resources/Sounds")

struct Tone {
    let frequency: Double
    let start: Double
    let duration: Double
    let gain: Double
    let attack: Double
    let release: Double
}

struct SoundSpec {
    let fileName: String
    let duration: Double
    let tones: [Tone]
    let noiseGain: Double
}

let specs: [SoundSpec] = [
    SoundSpec(fileName: "ping.wav", duration: 0.42, tones: [
        Tone(frequency: 880, start: 0.00, duration: 0.20, gain: 0.30, attack: 0.012, release: 0.18),
        Tone(frequency: 1320, start: 0.10, duration: 0.20, gain: 0.18, attack: 0.010, release: 0.16)
    ], noiseGain: 0.000),
    SoundSpec(fileName: "pop.wav", duration: 0.28, tones: [
        Tone(frequency: 520, start: 0.00, duration: 0.14, gain: 0.34, attack: 0.006, release: 0.10),
        Tone(frequency: 780, start: 0.055, duration: 0.10, gain: 0.16, attack: 0.006, release: 0.08)
    ], noiseGain: 0.010),
    SoundSpec(fileName: "glass.wav", duration: 0.56, tones: [
        Tone(frequency: 1046.5, start: 0.00, duration: 0.36, gain: 0.20, attack: 0.018, release: 0.30),
        Tone(frequency: 1568.0, start: 0.03, duration: 0.32, gain: 0.16, attack: 0.014, release: 0.28),
        Tone(frequency: 2093.0, start: 0.07, duration: 0.28, gain: 0.10, attack: 0.010, release: 0.25)
    ], noiseGain: 0.000),
    SoundSpec(fileName: "pulse.wav", duration: 0.40, tones: [
        Tone(frequency: 660, start: 0.00, duration: 0.11, gain: 0.22, attack: 0.010, release: 0.09),
        Tone(frequency: 660, start: 0.17, duration: 0.12, gain: 0.20, attack: 0.010, release: 0.10)
    ], noiseGain: 0.000),
    SoundSpec(fileName: "bell.wav", duration: 0.62, tones: [
        Tone(frequency: 784, start: 0.00, duration: 0.42, gain: 0.24, attack: 0.016, release: 0.36),
        Tone(frequency: 1175, start: 0.02, duration: 0.38, gain: 0.13, attack: 0.016, release: 0.32),
        Tone(frequency: 1760, start: 0.04, duration: 0.30, gain: 0.07, attack: 0.012, release: 0.28)
    ], noiseGain: 0.000),
    SoundSpec(fileName: "tap.wav", duration: 0.20, tones: [
        Tone(frequency: 720, start: 0.00, duration: 0.075, gain: 0.22, attack: 0.004, release: 0.050)
    ], noiseGain: 0.018),
    SoundSpec(fileName: "bloom.wav", duration: 0.58, tones: [
        Tone(frequency: 523.25, start: 0.00, duration: 0.30, gain: 0.18, attack: 0.030, release: 0.25),
        Tone(frequency: 659.25, start: 0.07, duration: 0.32, gain: 0.16, attack: 0.030, release: 0.28),
        Tone(frequency: 987.77, start: 0.15, duration: 0.26, gain: 0.12, attack: 0.025, release: 0.22)
    ], noiseGain: 0.000),
    SoundSpec(fileName: "signal.wav", duration: 0.48, tones: [
        Tone(frequency: 740, start: 0.00, duration: 0.16, gain: 0.24, attack: 0.010, release: 0.13),
        Tone(frequency: 990, start: 0.13, duration: 0.18, gain: 0.20, attack: 0.010, release: 0.14)
    ], noiseGain: 0.000),
    SoundSpec(fileName: "lift.wav", duration: 0.46, tones: [
        Tone(frequency: 587.33, start: 0.00, duration: 0.18, gain: 0.18, attack: 0.018, release: 0.15),
        Tone(frequency: 880.00, start: 0.12, duration: 0.24, gain: 0.24, attack: 0.018, release: 0.20)
    ], noiseGain: 0.000),
    SoundSpec(fileName: "soft-alert.wav", duration: 0.52, tones: [
        Tone(frequency: 698.46, start: 0.00, duration: 0.18, gain: 0.20, attack: 0.018, release: 0.15),
        Tone(frequency: 932.33, start: 0.12, duration: 0.20, gain: 0.16, attack: 0.018, release: 0.16),
        Tone(frequency: 1244.51, start: 0.24, duration: 0.18, gain: 0.12, attack: 0.015, release: 0.14)
    ], noiseGain: 0.000)
]

try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

for spec in specs {
    let samples = render(spec)
    let data = wavData(samples: samples)
    try data.write(to: outputDirectory.appendingPathComponent(spec.fileName))
}

func render(_ spec: SoundSpec) -> [Int16] {
    let totalSamples = Int(spec.duration * Double(sampleRate))
    var samples = Array(repeating: 0.0, count: totalSamples)
    var randomState: UInt64 = 0x1234_5678_9abc_def0

    for tone in spec.tones {
        let startSample = Int(tone.start * Double(sampleRate))
        let toneSamples = min(Int(tone.duration * Double(sampleRate)), totalSamples - startSample)
        guard toneSamples > 0 else { continue }

        for index in 0..<toneSamples {
            let absoluteIndex = startSample + index
            let t = Double(index) / Double(sampleRate)
            let envelope = envelope(at: t, duration: tone.duration, attack: tone.attack, release: tone.release)
            let shimmer = 1.0 + 0.006 * sin(2.0 * Double.pi * 6.0 * t)
            samples[absoluteIndex] += sin(2.0 * Double.pi * tone.frequency * shimmer * t) * tone.gain * envelope
        }
    }

    if spec.noiseGain > 0 {
        let noiseSamples = min(Int(0.055 * Double(sampleRate)), totalSamples)
        for index in 0..<noiseSamples {
            randomState = randomState &* 6_364_136_223_846_793_005 &+ 1
            let value = Double(Int64(bitPattern: randomState >> 16) % 2000) / 1000.0 - 1.0
            let t = Double(index) / Double(sampleRate)
            samples[index] += value * spec.noiseGain * envelope(at: t, duration: 0.055, attack: 0.002, release: 0.050)
        }
    }

    return samples.map { sample in
        let clipped = max(-0.92, min(0.92, sample))
        return Int16(clipped * Double(Int16.max))
    }
}

func envelope(at time: Double, duration: Double, attack: Double, release: Double) -> Double {
    if time < attack {
        return time / attack
    }

    let releaseStart = max(attack, duration - release)
    if time > releaseStart {
        return max(0, (duration - time) / release)
    }

    return 1
}

func wavData(samples: [Int16]) -> Data {
    var data = Data()
    let byteRate = sampleRate * 2
    let subchunk2Size = samples.count * 2
    let chunkSize = 36 + subchunk2Size

    data.appendASCII("RIFF")
    data.appendUInt32LE(UInt32(chunkSize))
    data.appendASCII("WAVE")
    data.appendASCII("fmt ")
    data.appendUInt32LE(16)
    data.appendUInt16LE(1)
    data.appendUInt16LE(1)
    data.appendUInt32LE(UInt32(sampleRate))
    data.appendUInt32LE(UInt32(byteRate))
    data.appendUInt16LE(2)
    data.appendUInt16LE(16)
    data.appendASCII("data")
    data.appendUInt32LE(UInt32(subchunk2Size))

    for sample in samples {
        data.appendUInt16LE(UInt16(bitPattern: sample))
    }

    return data
}

extension Data {
    mutating func appendASCII(_ value: String) {
        append(contentsOf: value.utf8)
    }

    mutating func appendUInt16LE(_ value: UInt16) {
        append(UInt8(value & 0xff))
        append(UInt8((value >> 8) & 0xff))
    }

    mutating func appendUInt32LE(_ value: UInt32) {
        append(UInt8(value & 0xff))
        append(UInt8((value >> 8) & 0xff))
        append(UInt8((value >> 16) & 0xff))
        append(UInt8((value >> 24) & 0xff))
    }
}
