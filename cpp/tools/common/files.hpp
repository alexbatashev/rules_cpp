#pragma once

#include "static_string.hpp"

#include <cstddef>
#include <cstdio>
#include <filesystem>
#include <iostream>
#include <string>
#include <string_view>
#include <vector>

#include <sys/stat.h>
#include <sys/types.h>
#ifndef WIN32
#include <fcntl.h>
#include <sys/mman.h>
#include <unistd.h>
#endif

#ifdef WIN32
#define stat _stat
#endif

size_t last_modified(const static_string<2048> &path) {
  struct stat result;
  if (stat(path.data(), &result) == 0) {
    auto modTime = result.st_mtime;
    return static_cast<size_t>(modTime);
  }

  return -1;
}

class map_file {
public:
  map_file() = default;
  map_file(const map_file &) = delete;
  map_file &operator=(const map_file &) = delete;
  map_file(map_file &&other) {
    fd = other.fd;
    len = other.len;
    ptr = other.ptr;
    other.fd = -1;
    other.ptr = nullptr;
  }
  map_file &operator=(map_file &&other) {
    fd = other.fd;
    len = other.len;
    ptr = other.ptr;
    other.fd = -1;
    other.ptr = nullptr;

    return *this;
  }

  static map_file create(std::string_view path, size_t len) {
    int fd = ::open(path.data(), O_RDWR | O_CREAT | O_TRUNC, 0666);
    if (fd == -1) {
      perror("Failed to open a file");
      std::cerr << "Path: " << path << "\n";
      std::abort();
    }

    if (ftruncate(fd, len) != 0) {
      perror("Failed to resize a file");
      std::abort();
    }

    return map_file(fd, len);
  }

  static map_file open(std::string_view path) {
    struct stat st;
    stat(path.data(), &st);

    int fd = ::open(path.data(), O_RDONLY);
    if (fd == -1) {
      perror("Failed to open a file");
      std::cerr << "Path: " << path << "\n";
      std::abort();
    }

    return map_file(fd, st.st_size, true);
  }

  void *data() { return ptr; }

  const void *data() const { return ptr; }

  ~map_file() {
    if (ptr) {
      munmap(ptr, len);
      close(fd);
    }
  }

  size_t size() const { return len; }

private:
  map_file(int fd, size_t len, bool readonly = false) : fd(fd), len(len) {
    int flags = PROT_READ;
    int mode = MAP_FILE;
    if (!readonly) {
      flags |= PROT_WRITE;
      mode |= MAP_SHARED;
    } else {
      mode |= MAP_PRIVATE;
    }
    ptr = mmap(nullptr, len, flags, mode, fd, 0);
    if (ptr == MAP_FAILED) {
      perror("Failed to map a file");
      std::abort();
    }
  }

  int fd = -1;
  size_t len = 0;
  void *ptr = nullptr;
};

inline bool file_exists(std::string_view prefix, std::string_view filename) {
  return false;
}