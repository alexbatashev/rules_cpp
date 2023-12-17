#pragma once

#include <cstddef>

template <typename T> size_t aligned_offset(size_t offset) {
  size_t alignment = alignof(T);
  if (offset % alignment == 0) {
    return offset;
  }

  return alignment * (offset / alignment + 1);
}