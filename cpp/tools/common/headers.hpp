#pragma once

#include "files.hpp"
#include "static_string.hpp"

#include <string_view>

static constexpr size_t HEADERS_VERSION = 0;

struct IncludeDir {
  explicit IncludeDir(static_string<> path) : path(path) {}

  bool operator<(const IncludeDir &rhs) { return path < rhs.path; }
  bool operator==(const IncludeDir &rhs) { return path == rhs.path; }
  static_string<> path;
};

struct HeaderFile {
  HeaderFile(static_string<> owner, static_string<> path)
      : owner(owner), path(path), timestamp(0) {}
  bool operator<(const HeaderFile &rhs) { return path < rhs.path; }
  bool operator==(const HeaderFile &rhs) {
    return path == rhs.path && owner == rhs.owner;
  }

  static_string<> owner;
  static_string<> path;
  size_t timestamp;
};

class Database {
public:
  template <typename T> class range {
  public:
    range(const T *ptr, size_t len) : ptr(ptr), len(len) {}

    const T *begin() const { return ptr; }

    const T *end() const { return ptr + len; }

  private:
    const T *ptr;
    size_t len;
  };

  explicit Database(std::string_view path) {
    db = std::move(map_file::open(path));
    const size_t *data = static_cast<size_t *>(db.data());
    if (data[0] != HEADERS_VERSION) {
      std::cerr << "Incompatible headers DB version. ";
      std::cerr << "Expected " << HEADERS_VERSION << " ";
      std::cerr << "got " << data[0] << ". ";
      std::cerr << "Clean build may help.\n";
      std::abort();
    }
  }

  range<IncludeDir> includes() const {
    const size_t *data = static_cast<const size_t *>(db.data());
    const void *includesStart = reinterpret_cast<const char *>(data) + data[1];
    return range<IncludeDir>(static_cast<const IncludeDir *>(includesStart),
                             data[2]);
  }

  range<HeaderFile> headers() const {
    const size_t *data = static_cast<const size_t *>(db.data());
    const void *headersStart = reinterpret_cast<const char *>(data) + data[3];
    return range<HeaderFile>(static_cast<const HeaderFile *>(headersStart),
                             data[4]);
  }

private:
  map_file db;
};