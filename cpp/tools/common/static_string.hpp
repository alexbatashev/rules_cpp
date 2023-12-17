#pragma once

#include <array>
#include <cassert>
#include <cstddef>
#include <cstring>
#include <iostream>
#include <string>
#include <string_view>

template <size_t MaxLen = 2048> class static_string {
public:
  static_string() = default;
  explicit static_string(const char *str) {
    mLen = std::strlen(str);
    std::cerr << "len = " << mLen << " data " << str << "\n";
    assert(mLen != 0);
    assert(mLen < MaxLen);
    std::strncpy(mString, str, mLen);
    mString[mLen] = '\0';
  }

  const char *data() const { return mString; }

  size_t size() const { return mLen; }

  bool operator<(const static_string &rhs) {
    int val = std::strncmp(mString, rhs.mString, std::min(mLen, rhs.mLen));
    if (val == 0)
      return mLen < rhs.mLen;
    return val < 0;
  }
  bool operator>(const static_string &rhs) {
    int val = std::strncmp(mString, rhs.mString, std::min(mLen, rhs.mLen));
    if (val == 0)
      return mLen > rhs.mLen;
    return val > 0;
  }
  bool operator==(const static_string &rhs) {
    if (mLen != rhs.mLen)
      return false;
    return std::strncmp(mString, rhs.mString, std::min(mLen, rhs.mLen)) == 0;
  }

  operator std::string_view() const noexcept {
    size_t len = mLen;
    // FIXME: why is this required?
    if (len == 0)
      len = std::strlen(mString);
    std::cerr << "strlen = " << len << "\n";
    return std::string_view{mString, len};
  }

  std::string str() const {
    // FIXME: why is this required?
    size_t len = mLen;
    if (len == 0)
      len = std::strlen(mString);
    std::cerr << "strlen = " << len << "\n";
    return std::string{mString, len};
  }

private:
  size_t mLen = 0;
  char mString[MaxLen];
};