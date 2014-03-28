Basic types
===========

Basic types are your bog standard primitive data types for storing
values. They are directly mapped to the underlying C types.

The built in datatypes for integer values:

    // 64, 32, 16 and 8 bit signed integer
    type i64 = C int64_t
    type i32 = C int32_t
    type i16 = C int16_t
    type i8 = C int8_t

    // 64, 32, 16 and 8 bit unsigned integer
    type u64 = C uint64_t
    type u32 = C uint32_t
    type u16 = C uint16_t
    type u8 = C uint8_t

The built in datatypes for floating point values:

    // 64 and 32 bit floating point
    type f64 = C double
    type f32 = C float

