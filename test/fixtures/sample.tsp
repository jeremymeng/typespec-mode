import "@typespec/http";
using TypeSpec.Http;

namespace MyService;

model Thing {
  id: int32;
  name: string;
  notes: """
    Multi-line
    notes here.
  """;
  count: 42;
}

@doc("Service description")
@@route("/api")
namespace Inner {
  @get
  op listThings(): Thing[];
}

interface ThingService {
  read(id: int32): Thing;
}

union Status { active: "active", inactive: "inactive" }
enum Role { admin, user }
scalar UnixTimestamp extends int64;
alias ThingId = int32;
