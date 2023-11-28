# Intro

Welcome to **PostgresClientORM**, the **ORM** for data in **PostgreSQL**

## Overview

**PostgresClientORM** is an **ORM** for storing objects in Postgres. It uses the package *PostgresNIO* for the connection to Postgres. **PostgresClientORM** has the advantage over **Fluent** that it's more Swift friendly, faster, and has a lower memory footprint for loaded objects. The advantage of Fluent us that it's database agnostic.

### Connection

The connection to **Postgres** database is controlled via environment variables. If the environment **DATABASE_URL** exists, it is used to control the connection, otherwise the set of following enviroment variables is used:
- **DATABASE_HOST**
- **DATABASE_PORT** (defaults to 5432 if not present)
- **DATABASE_USER**
- **DATABASE_PASSWORD**
- **DATABASE_SSL** (defaults to true if not present)

If using in **VAPOR** you need to connect **PostresClientORM** to the app event loop, and optionally to the logger. So early in your configure function (before any database access) do:

```swift
PostgresClientORM.configure(logger: app.logger, eventLoop: app.eventLoopGroup.next())
```

The logger parameter is optional, ommitting it will cause **PostgresClientORM** to create it's own logger.

### Models

To create models use the ``@TableObject`` macro. Example:
```Swift
@TableObject(table: "weather", idType: UUID.self)
struct Weather {
  var city: String
  var tempLo: Int
  var tempHi: Int
}
```

Models can be a ``struct`` or a ``final class``. The macro makes the object conform to the ``TableObject`` protocol. The macro accepts the following parameters:

| Parameter | Default/Required | Explanation |
|-----------|:-------:|-------------|
| columns: | .snakeCase | ``.snakeCase`` or ``.camelCase``. Cpecifies how the column name is derived. |
| table: | **required** | The name of the table holding these objects. |
| idType: | UUID.self | The type of the id column, e.g. ``Int.self`` |
| idName: | "id" | The name of the id column. The id property will alwas be `id` |
| trackDirty: | true | `true` / `false` if to keep track if the object is dirty, i.e. changed since it was loaded from the database |
| codable: | .none | Also make the object Codable, value can be `.none`/`.snakeCase`/`.camelCase` |

The object will have an `id` property of type `idType` to hold it's database id.

if `trackDirty` is `true` (default) the object will conform to `SaveableTableObject` and will have the `save()` func which will check if the object is dirty, it will update, if the object is new it will insert otherwise it will do nothing. The object will also have a `isDirty()` func that will return a bool stating if the object is dirty.

A good practice is to have an `idType` of type `UUID.self`. In which case **PostgresClientORM** knows to set it on it's own. Autoincremented ids are not yet support (*on the todo list*).

You can set a custom column name for a `var` by prefixing it with the `@Column(name "custom_name")` macro. A property can be ignored by prefixing it with the `@ColumnIgnored` macro. In a similar manner if you specify in the `@TableObject` macro to also conform to `Codable`, a custom `CodingKey` can be set with `@Coding(key: "customKey")` and ignored with `@CodingKeysIgnored`

### FieldSubset

A `FieldSubset` is struct that can encode it's properties together with the it's parent. For example:
```swift
@TableObject(table: "weather", idToype: UUID.self)
struct Weather {
    var city: String
    var temp: TempRange
}

@Columns
struct TempRange {
    let lo: Double
    let hi: Double
}
```

This will encode the temp propperty in the column **temp_lo** and **temp_hi** of table **weather**. A `FieldSubset` can also be used to generate manual encoding of a property to the table, use the `Column` named `root` (string value ""), for example:

```swift
enum CityType: FieldSubset {
    case metropolitan
    case village

    enum Columns: String, CodingKey {
        case root = ""
    }

    init(row: RowDecoder<Columns>) throws {
       let v = try row.decode(Int.self, forKey: .root)
       switch v {
        case 1:
            self = .metropolitan
        default:
            self = .village
       }
    }

    func encode(row: RowEncoder<Columns>) throws {
        switch self {
            case .metropolitan: 
                try row.encode(1, forKey: .root)
            case .village: 
                try row.encode(2, forKey: .root)
        }
   }
}
```

This is just an example. It is not necessary to declare `RawRepresentable` enums as `FieldSet` as by default they are and encode their `rawValue`.

### Querying

Create a query with the type functions `select()`, `delete()` or `count()`. Example:
```swift
let cities = try await Weather.select()
    .where {
        Weather.column(.temp) -› TempRange.column(.lo) > 0
        Weather.column(.temp) -› TempRange.column(.hi) < 35
    }
    .limit(20)
    .execute()
```

#### Explanation:

the `.where { ... }` is used to set SQL where conditions. By default the conditions are merged using the AND operator. You can place conditions in an `Or { ... }` block to have them grouped with the OR operator. The `-›` operator (the › is generated by option-shift-4) is used for columns of a `FieldSubset`, so `Weather.column(.temp) -› TempRange.column(.lo) > 0` resolves to the column named `temp_lo`. The `count()` query return value is just an **Int** of the count of items found.

#### Result Sequence

In the above example, `cities` if an array of the results of type `[Weather]`. A more optimal approach is to use a result sequence, this will fetch the SQL results row by row and decode them a row at a time, not storing all the results in memroy. Example:
```swift
let query = try Weather.select().where {
    Weather.column(.city) =* "N" // the =* operator uses the SQL LIKE operator to find strings with the N prefix. 
                                 // Similar operators are *= and *=* for suffix and contains respectively.
}
for try await city in query.results {
    ... // do something with a city
}
```

### Migrations

**PostgresClientORM** supports schema migrations. For example:
```swift
func migrate() async throws {
  let migrations = Migrations()

  try await migrations.add("v1") {
    try await table("weather") {
        column("city", type: .string)
    }
    .create()
  }

  try await migrations.add("v2") {
    try await table("weather) {
        column("temp_lo", type: .double)
        column("temp_hi", type: .double)
    }
    .update()
  }
  
  try await migrations.perform()
}
```

Columns can have the following modifiers: `drop()`, `rename(:)` (arg is new column name), `update(:)` (arg is new column type), `defaultValue(:)`, `unique()`, `notNull()`, `references(table:column:onDelete:)` (is a foreign key referencing anoher table) and `primaryKey()`

### Transactions

It is possible to perform database operations in a database transaction. To perform a transaction:
```swift
try await Database.handler.transaction { tid in
    // perform transaction operations
    // remember to pass transaction connection to any database operation
    var city = try await Weather.fetch(id: city_id, transactionConnection: tid)
    city.temp.lo = -10
    try await city.save(transactionConnection: tid)
}
```

Its important to pass the transaction connection to database operations in the block, otherwise the operation will not participate in the transacction. The transaction will appear atomic to other users of the database. If the block terminates normally the transaction is commited. If the block throws the transaction is rolled back.
