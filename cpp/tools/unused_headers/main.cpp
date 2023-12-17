#include "ctre-unicode.hpp"
#include "files.hpp"
#include "headers.hpp"

#include <fstream>
#include <iostream>
#include <queue>
#include <string>
#include <string_view>

inline constexpr auto pattern =
    ctll::fixed_string{"#include\\s*(<|\")([a-zA-Z0-9~\\.\\\\\\/]+)(>|\")"};

std::vector<std::string_view> find_all_headers(const map_file &file) {
  std::string_view content{static_cast<const char *>(file.data()), file.size()};
  std::vector<std::string_view> headers;
  for (auto match : ctre::search_all<pattern, ctre::singleline>(content)) {
    std::string_view m = match.get<2>();
    headers.push_back(m);
  }

  return headers;
}

void find_used_headers(const Database &db,
                       const std::vector<std::string_view> &candidates,
                       std::vector<std::string> &usedHeaders,
                       std::queue<std::string_view> &queue) {
  for (auto cand : candidates) {
    for (auto include : db.includes()) {
      std::filesystem::path path =
          std::filesystem::path(std::string_view{include.path.data()}) / cand;
      if (std::filesystem::exists(path)) {
        usedHeaders.push_back(path.c_str());
        queue.push(usedHeaders.back());
      }
    }
  }
}

int main(int argc, char *argv[]) {
  if (argc != 4) {
    std::cerr << "Wrong number of arguments";
    return 1;
  }

  std::string_view dbPath{argv[1]};
  std::string_view srcPath{argv[2]};
  std::string unusedPath{argv[3]};

  Database db(dbPath);

  std::vector<std::string> usedHeaders;

  // Lifetime of these values is bound either to usedHeaders or to the main
  // itself.
  std::queue<std::string_view> queue;
  queue.push(srcPath);

  while (!queue.empty()) {
    std::string_view path = queue.front();
    queue.pop();

    auto file = map_file::open(path);
    auto headers = find_all_headers(file);
    find_used_headers(db, headers, usedHeaders, queue);
  }

  // FIXME: this should work just fine with std::string_view.
  std::vector<std::string> unusedHeaders;
  unusedHeaders.reserve(
      std::distance(db.headers().begin(), db.headers().end()));

  std::ofstream ofs{unusedPath};
  for (auto hdr : db.headers()) {
    unusedHeaders.push_back(std::string{hdr.path.data()});
  }

  auto end = unusedHeaders.end();

  for (const auto &hdr : usedHeaders) {
    end = std::remove_if(unusedHeaders.begin(), end,
                         [hdr](std::string_view cand) { return cand == hdr; });
  }

  for (auto it = unusedHeaders.begin(); it != end; it++) {
    ofs << *it << "\n";
  }

  ofs.close();

  return 0;
}