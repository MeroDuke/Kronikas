#ifndef RUNNER_PROBE_CHANNEL_H_
#define RUNNER_PROBE_CHANNEL_H_

#include <windows.h>
#include <wincrypt.h>
#include <commdlg.h>

#include "utils.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <vector>

inline void RegisterProbeChannel(flutter::BinaryMessenger* messenger, HWND owner) {
  flutter::MethodChannel<flutter::EncodableValue> channel(
      messenger, "hu.akihabarai.kronikas_platform_probe/storage",
      &flutter::StandardMethodCodec::GetInstance());
  channel.SetMethodCallHandler([owner](const auto& call, auto result) {
    if (call.method_name() == "pickStoryDocument") {
      wchar_t path[32768] = {};
      OPENFILENAMEW options{};
      options.lStructSize = sizeof(options);
      options.hwndOwner = owner;
      options.lpstrFilter = L"Krónikás dokumentumok\0*.docx;*.txt;*.md\0";
      options.lpstrFile = path;
      options.nMaxFile = static_cast<DWORD>(sizeof(path) / sizeof(path[0]));
      options.Flags = OFN_FILEMUSTEXIST | OFN_PATHMUSTEXIST | OFN_NOCHANGEDIR;
      if (GetOpenFileNameW(&options)) {
        result->Success(flutter::EncodableValue(Utf8FromUtf16(path)));
      } else if (CommDlgExtendedError() == 0) {
        result->Success();
      } else {
        result->Error("document_picker_failed");
      }
      return;
    }
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
