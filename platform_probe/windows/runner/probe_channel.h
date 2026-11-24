#ifndef RUNNER_PROBE_CHANNEL_H_
#define RUNNER_PROBE_CHANNEL_H_

#include <windows.h>
#include <wincrypt.h>

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <vector>

inline void RegisterProbeChannel(flutter::BinaryMessenger* messenger) {
  flutter::MethodChannel<flutter::EncodableValue> channel(
      messenger, "hu.akihabarai.kronikas_platform_probe/storage",
      &flutter::StandardMethodCodec::GetInstance());
  channel.SetMethodCallHandler([](const auto& call, auto result) {
    const bool encrypt = call.method_name() == "protect";
    if (!encrypt && call.method_name() != "unprotect") {
      result->NotImplemented();
      return;
    }
    const auto* bytes = call.arguments()
                            ? std::get_if<std::vector<uint8_t>>(call.arguments())
                            : nullptr;
    if (!bytes || bytes->empty() || bytes->size() > 4096) {
      result->Error("invalid_input");
      return;
    }
    // DPAPI's input parameter is mutable even though it reads the payload.
    std::vector<uint8_t> input_bytes(*bytes);
    DATA_BLOB input{static_cast<DWORD>(input_bytes.size()), input_bytes.data()};
    DATA_BLOB output{};
    const BOOL ok = encrypt
        ? CryptProtectData(&input, nullptr, nullptr, nullptr, nullptr,
                           CRYPTPROTECT_UI_FORBIDDEN, &output)
        : CryptUnprotectData(&input, nullptr, nullptr, nullptr, nullptr,
                             CRYPTPROTECT_UI_FORBIDDEN, &output);
    if (!ok) {
      result->Error("dpapi_failed");
      return;
    }
    const std::vector<uint8_t> payload(output.pbData,
                                       output.pbData + output.cbData);
    LocalFree(output.pbData);
    result->Success(flutter::EncodableValue(payload));
  });
}

#endif  // RUNNER_PROBE_CHANNEL_H_
