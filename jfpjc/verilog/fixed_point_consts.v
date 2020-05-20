

// all of these constants are positive; they are rounded and multiplied by 128 to match the 7q8 format.

// k * cos((n * pi) / 16) for 1c3 = 0.8314696123 * 0.35355339059
// 75.2560385539
`define _1C3_COS_7Q8 (9'd75)

// k * sin((n * pi) / 16) for 1c3 = 0.5555702330 * 0.35355339059
// 50.2844773345
`define _1C3_SIN_7Q8 (9'd50)

// k * cos((n * pi) / 16) for 1c1 = 0.9807852804 * 0.35355339059
// 88.7705500995
`define _1C1_COS_7Q8 (9'd89)

// k * sin((n * pi) / 16) for 1c1 = 0.1950903220 * 0.35355339059
// 17.6575602725
`define _1C1_SIN_7Q8 (9'd18)

// k * cos((n * pi) / 16) for sqrt(2)c1 = 0.54119610014 * 0.35355339059
// 48.9834793417
`define _R2C1_COS_7Q8 (9'd49)

// k * sin((n * pi) / 16) for sqrt(2)c1 = 1.30656296488 * 0.35355339059
// 118.256580161
`define _R2C1_SIN_7Q8 (9'd118)

// 1.41421356237
// 362.038671967
`define _SQRT2_7Q8 (9'd362)

// 1.41421356237 * 0.25
// 90.5096679917
`define _SQRT2_OVER4_7Q8 (9'd90)
