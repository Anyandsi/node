/* Path destination.
 *
 * Author: Steffen Vogel <post@steffenvogel.de>
 * SPDX-FileCopyrightText: 2014-2023 Institute for Automation of Complex Power Systems, RWTH Aachen University
 * SPDX-License-Identifier: Apache-2.0
 */

#pragma once

#include <memory>
#include <mutex>
#include <vector>

#include <villas/mapping.hpp>
#include <villas/queue.h>
#include <villas/signal_list.hpp>

namespace villas {
namespace node {

// Forward declarations
class Node;
class Path;
struct Sample;
class PathDestination;

class PathDestination {
  friend Path;

public:
  using Ptr = std::shared_ptr<PathDestination>;

protected:
  Node *node;
  Path *path;
  MappingEntry::Ptr output_mapping_entry;

  struct CQueue queue;

public:
  PathDestination(Path *p, Node *n, MappingEntry::Ptr me = nullptr);

  ~PathDestination();

  int prepare(int queuelen);

  void check();

  static void enqueueAll(class Path *p, const struct Sample *const smps[],
                         unsigned cnt);

  void write();

  Node *getNode() const { return node; }

  Path *getPath() const { return path; }

  MappingEntry::Ptr getOutputMappingEntry() const {
    return output_mapping_entry;
  }

  bool isOutputMapped() const { return output_mapping_entry != nullptr; }
};

using PathDestinationList = std::vector<PathDestination::Ptr>;

} // namespace node
} // namespace villas
