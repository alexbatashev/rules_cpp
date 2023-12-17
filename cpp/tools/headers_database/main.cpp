#include "alignment.hpp"
#include "files.hpp"
#include "headers.hpp"
#include "json.hpp"
#include "static_string.hpp"

#include <fstream>
#include <iostream>
#include <string>
#include <vector>

using json = nlohmann::json;

int main(int argc, char *argv[]) {
  if (argc != 3) {
    std::cerr << "Wrong number of arguments";
    return 1;
  }

  std::string inputFile{argv[1]};
  std::string outputFile{argv[2]};

  std::ifstream f(inputFile);
  json data = json::parse(f);

  std::vector<IncludeDir> includes;
  std::vector<HeaderFile> headers;

  for (auto include : data["includes"]) {
    std::string inc = include;
    includes.emplace_back(static_string<>(inc.c_str()));
  }

  auto incDel = std::unique(includes.begin(), includes.end());
  includes.erase(incDel, includes.end());

  for (auto hdr : data["headers"]) {
    std::string path = hdr["path"];
    std::string owner = hdr["owner"];
    headers.emplace_back(static_string<>(owner.c_str()),
                         static_string<>(path.c_str()));
  }

  std::sort(headers.begin(), headers.end());
  auto hdrDel = std::unique(headers.begin(), headers.end());
  headers.erase(hdrDel, headers.end());

  for (auto &hdr : headers) {
    hdr.timestamp = last_modified(hdr.path);
  }

  size_t fileSize = 4 * sizeof(size_t) + sizeof(IncludeDir) * includes.size() +
                    sizeof(HeaderFile) * headers.size();

  map_file file = map_file::create(outputFile, fileSize);

  size_t *db = static_cast<size_t *>(file.data());

  size_t includesOffset = aligned_offset<IncludeDir>(8 * sizeof(size_t));
  size_t headersOffset = aligned_offset<HeaderFile>(
      includesOffset + includes.size() * sizeof(IncludeDir));

  db[0] = HEADERS_VERSION;
  db[1] = includesOffset;
  db[2] = includes.size();
  db[3] = headersOffset;
  db[4] = headers.size();
  db[5] = 0; // reserved
  db[6] = 0; // reserved
  db[7] = 0; // reserved

  std::memcpy(reinterpret_cast<char *>(db) + includesOffset, includes.data(),
              sizeof(IncludeDir) * includes.size());
  std::memcpy(reinterpret_cast<char *>(db) + headersOffset, headers.data(),
              sizeof(HeaderFile) * headers.size());

  return 0;
}