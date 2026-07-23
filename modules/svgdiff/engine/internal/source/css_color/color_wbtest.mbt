// Copyright 2026 International Digital Economy Academy
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

///|
test "CSS Color 3 equivalent spellings share one canonical sRGB value" {
  let expected = Resolved({ red: 255, green: 0, blue: 0, alpha: 1.0 })
  for
    value in [
      "red", "RED", "#f00", "#ff0000", "rgb(255,0,0)", "rgb(100%, 0%, 0%)", "rgba(255,0,0,1)",
      "hsl(0,100%,50%)", "hsla(360,100%,50%,100%)",
    ] {
    assert_eq(parse_solid_color(value), expected)
  }
}

///|
test "solid colors retain independent alpha" {
  assert_eq(
    parse_solid_color("#0f08"),
    Resolved({ red: 0, green: 255, blue: 0, alpha: 136.0 / 255.0 }),
  )
  assert_eq(
    parse_solid_color("#00ff0080"),
    Resolved({ red: 0, green: 255, blue: 0, alpha: 128.0 / 255.0 }),
  )
  assert_eq(
    parse_solid_color("rgba(0,255,0,0.25)"),
    Resolved({ red: 0, green: 255, blue: 0, alpha: 0.25 }),
  )
  assert_eq(
    parse_solid_color("transparent"),
    Resolved({ red: 0, green: 0, blue: 0, alpha: 0.0 }),
  )
}

///|
test "RGB and HSL components clamp and hue wraps" {
  assert_eq(
    parse_solid_color("rgb(300,-1,127.5)"),
    Resolved({ red: 255, green: 0, blue: 128, alpha: 1.0 }),
  )
  assert_eq(
    parse_solid_color("hsl(-120,100%,50%)"),
    Resolved({ red: 0, green: 0, blue: 255, alpha: 1.0 }),
  )
}

///|
test "invalid and environment-dependent colors stay distinct" {
  assert_eq(parse_solid_color("currentColor"), CurrentColor)
  assert_eq(parse_solid_color("ButtonFace"), SystemColor("buttonface"))
  for
    value in [
      "", "not-a-color", "#12", "#ggg", "rgb(1,2)", "rgb(10%,20,30%)", "rgba(1,2,3)",
      "hsl(0,1,2)", "hsl(0,100%,50%,1)", "lab(50% 0 0)",
    ] {
    assert_eq(parse_solid_color(value), Invalid)
  }
}

///|
test "alpha values accept numbers and percentages and clamp" {
  assert_eq(parse_alpha_value(".25"), Some(0.25))
  assert_eq(parse_alpha_value("25%"), Some(0.25))
  assert_eq(parse_alpha_value("-1"), Some(0.0))
  assert_eq(parse_alpha_value("200%"), Some(1.0))
  assert_eq(parse_alpha_value("1 trailing"), None)
}

///|
test "representative extended named colors match the CSS table" {
  assert_eq(
    parse_solid_color("lightgoldenrodyellow"),
    Resolved({ red: 250, green: 250, blue: 210, alpha: 1.0 }),
  )
  guard parse_solid_color("tomato") is Resolved(color) else {
    fail("tomato must be a named color")
  }
  assert_eq(color.renderer_hex(), "#ff6347")
  assert_eq(color.signature(), "rgba(255,99,71,1)")
}

///|
test "every extended named color keyword is admitted" {
  let names = [
    "aliceblue", "antiquewhite", "aqua", "aquamarine", "azure", "beige", "bisque",
    "black", "blanchedalmond", "blue", "blueviolet", "brown", "burlywood", "cadetblue",
    "chartreuse", "chocolate", "coral", "cornflowerblue", "cornsilk", "crimson",
    "cyan", "darkblue", "darkcyan", "darkgoldenrod", "darkgray", "darkgreen", "darkgrey",
    "darkkhaki", "darkmagenta", "darkolivegreen", "darkorange", "darkorchid", "darkred",
    "darksalmon", "darkseagreen", "darkslateblue", "darkslategray", "darkslategrey",
    "darkturquoise", "darkviolet", "deeppink", "deepskyblue", "dimgray", "dimgrey",
    "dodgerblue", "firebrick", "floralwhite", "forestgreen", "fuchsia", "gainsboro",
    "ghostwhite", "gold", "goldenrod", "gray", "green", "greenyellow", "grey", "honeydew",
    "hotpink", "indianred", "indigo", "ivory", "khaki", "lavender", "lavenderblush",
    "lawngreen", "lemonchiffon", "lightblue", "lightcoral", "lightcyan", "lightgoldenrodyellow",
    "lightgray", "lightgreen", "lightgrey", "lightpink", "lightsalmon", "lightseagreen",
    "lightskyblue", "lightslategray", "lightslategrey", "lightsteelblue", "lightyellow",
    "lime", "limegreen", "linen", "magenta", "maroon", "mediumaquamarine", "mediumblue",
    "mediumorchid", "mediumpurple", "mediumseagreen", "mediumslateblue", "mediumspringgreen",
    "mediumturquoise", "mediumvioletred", "midnightblue", "mintcream", "mistyrose",
    "moccasin", "navajowhite", "navy", "oldlace", "olive", "olivedrab", "orange",
    "orangered", "orchid", "palegoldenrod", "palegreen", "paleturquoise", "palevioletred",
    "papayawhip", "peachpuff", "peru", "pink", "plum", "powderblue", "purple", "red",
    "rosybrown", "royalblue", "saddlebrown", "salmon", "sandybrown", "seagreen",
    "seashell", "sienna", "silver", "skyblue", "slateblue", "slategray", "slategrey",
    "snow", "springgreen", "steelblue", "tan", "teal", "thistle", "tomato", "turquoise",
    "violet", "wheat", "white", "whitesmoke", "yellow", "yellowgreen",
  ]
  assert_eq(names.length(), 147)
  for name in names {
    assert_true(parse_solid_color(name) is Resolved(_))
  }
}
