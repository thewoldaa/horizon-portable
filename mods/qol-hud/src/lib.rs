//! One HUD panel the player places and sizes themselves.
//!
//! Coordinates, facing, the time of day and the frame rate, in one panel.
//! Everything about where it sits and how big it is comes from the player's
//! page in Options > Mods:
//!
//! - **Corner**: which of the screen's four corners it is anchored to.
//! - **Nudge across / Nudge down**: slides it away from that corner, so it
//!   can sit anywhere, not only in a corner.
//! - **Line spacing** and **Padding**: the panel's size. The text itself is
//!   drawn in the HUD's own font, which a mod cannot scale (the mod API has
//!   no text scale), so this changes the panel's footprint and how airy it
//!   is rather than the size of the letters. For bigger text, raise the
//!   game's GUI Scale in Options > Video Settings.
//! - **What it shows**: each of the three lines can be turned off.
//!
//! The choices live in the mod's storage, so they survive a restart.
use horizon_mod_sdk::{
    Mod, Registration,
    game::{self, Clock, Player},
    render::{self, Corner, FillShape, Point, Rect, Shape, TextShape},
    storage,
    ui::{self, ButtonWidget, Widget},
};

/// The panel's backdrop: translucent black, as the game's own overlays.
const BACKGROUND: u32 = 0x7800_0000;
/// White text with a shadow, as the debug screen's.
const INK: u32 = 0xFF_FFFF;
/// The HUD font's line height at GUI scale 1.
const LINE: f32 = 9.0;

/// Settings page widget ids. Stable: the page's buttons echo them back.
const CORNER_BUTTON: u32 = 1;
const NUDGE_X_BUTTON: u32 = 2;
const NUDGE_Y_BUTTON: u32 = 3;
const SPACING_BUTTON: u32 = 4;
const PADDING_BUTTON: u32 = 5;
const COORDS_BUTTON: u32 = 6;
const TIME_BUTTON: u32 = 7;
const FPS_BUTTON: u32 = 8;

const CORNERS: [(Corner, &str, &str); 4] = [
    (Corner::TopLeft, "top_left", "Top left"),
    (Corner::TopRight, "top_right", "Top right"),
    (Corner::BottomLeft, "bottom_left", "Bottom left"),
    (Corner::BottomRight, "bottom_right", "Bottom right"),
];

/// Nudge steps, in GUI pixels, cycled by the buttons. 0 is flush with the
/// corner; the negative ones pull the panel back towards the middle.
const NUDGE: [f32; 13] = [
    -200.0, -120.0, -80.0, -48.0, -24.0, -12.0, 0.0, 12.0, 24.0, 48.0, 80.0, 120.0, 200.0,
];
const NUDGE_ZERO: usize = 6;

/// Line spacing choices, in GUI pixels. The first is the HUD's own line
/// height, so the panel reads like the debug screen.
const SPACING: [f32; 6] = [LINE, 11.0, 13.0, 15.0, 18.0, 22.0];
/// Padding around the text, in GUI pixels.
const PADDING: [f32; 6] = [1.0, 2.0, 3.0, 4.0, 6.0, 8.0];

/// Direction.fromYRot: yaw 0 faces south, 90 west.
fn facing(yaw: f32) -> &'static str {
    let i = (yaw / 90.0 + 0.5).floor() as i32 & 3;
    ["South (+Z)", "West (-X)", "North (-Z)", "East (+X)"][i as usize]
}

/// `Day 3, 14:05`: day time 0 is 6:00 on day 1.
fn time_of_day(clock: &Clock) -> String {
    let day = clock.day_time / 24000 + 1;
    let ticks = clock.day_time % 24000;
    let hours = (ticks / 1000 + 6) % 24;
    let minutes = ticks % 1000 * 60 / 1000;
    format!("Day {day}, {hours:02}:{minutes:02}")
}

struct Hud {
    corner: usize,
    nudge_x: usize,
    nudge_y: usize,
    spacing: usize,
    padding: usize,
    coords: bool,
    time: bool,
    fps: bool,
    /// What the panel showed last, so an unchanged one costs no call.
    shown: Vec<String>,
}

/// A stored index, clamped to the table it indexes.
fn stored_index(key: &str, fallback: usize, len: usize) -> usize {
    storage::get(key)
        .and_then(|b| String::from_utf8(b).ok())
        .and_then(|t| t.trim().parse::<usize>().ok())
        .filter(|i| *i < len)
        .unwrap_or(fallback)
}

fn stored_bool(key: &str, fallback: bool) -> bool {
    storage::get(key)
        .and_then(|b| String::from_utf8(b).ok())
        .map(|t| t.trim() == "true")
        .unwrap_or(fallback)
}

impl Hud {
    fn keep(&self) {
        let _ = storage::set("corner", self.corner.to_string().as_bytes());
        let _ = storage::set("nudge_x", self.nudge_x.to_string().as_bytes());
        let _ = storage::set("nudge_y", self.nudge_y.to_string().as_bytes());
        let _ = storage::set("spacing", self.spacing.to_string().as_bytes());
        let _ = storage::set("padding", self.padding.to_string().as_bytes());
        let _ = storage::set("coords", if self.coords { b"true" } else { b"false" });
        let _ = storage::set("time", if self.time { b"true" } else { b"false" });
        let _ = storage::set("fps", if self.fps { b"true" } else { b"false" });
    }

    /// The lines the panel shows now, in order.
    fn lines(&self, player: &Player) -> Vec<String> {
        let mut out = Vec::new();
        if self.coords {
            out.push(format!(
                "XYZ {:.0} / {:.0} / {:.0}",
                player.x.floor(),
                player.y.floor(),
                player.z.floor()
            ));
            out.push(format!("Facing {}", facing(player.yaw)));
        }
        if self.time {
            if let Some(clock) = game::get_clock() {
                out.push(time_of_day(&clock));
            }
        }
        if self.fps {
            let f = render::frame_stats();
            out.push(format!("{} fps", f.fps));
        }
        out
    }

    /// Draws the panel, or clears it when there is nothing to show.
    fn draw(&mut self, player: Option<&Player>) {
        let lines = match player {
            Some(p) => self.lines(p),
            None => Vec::new(),
        };
        if lines == self.shown {
            return;
        }
        self.shown = lines.clone();
        if lines.is_empty() {
            render::clear_corner();
            return;
        }

        let spacing = SPACING[self.spacing];
        let padding = PADDING[self.padding];
        let widest = lines
            .iter()
            .map(|l| render::text_width(l))
            .fold(0.0_f32, f32::max);
        let w = widest + padding * 2.0;
        // The last line's own height, not another spacing step.
        let h = spacing * (lines.len() as f32 - 1.0) + LINE + padding * 2.0;

        let mut shapes = Vec::with_capacity(lines.len() + 1);
        shapes.push(Shape::Fill(FillShape {
            rect: Rect {
                x: 0.0,
                y: 0.0,
                w,
                h,
            },
            color: BACKGROUND,
        }));
        for (i, line) in lines.iter().enumerate() {
            shapes.push(Shape::Text(TextShape {
                text: line.clone(),
                at: Point {
                    x: padding,
                    y: padding + spacing * i as f32,
                },
                color: INK,
                centered: false,
                shadow: true,
            }));
        }

        // The nudge slides the panel inside a box that is the screen's size,
        // so a positive nudge always moves it away from its own corner.
        let (sw, sh) = render::gui_size();
        let (x, y) = (NUDGE[self.nudge_x], NUDGE[self.nudge_y]);
        let (w2, h2) = match CORNERS[self.corner].0 {
            // Room to slide away from each edge; the panel sits at the
            // corner the game gives it when the nudge is 0.
            Corner::TopLeft => (w + x.max(0.0), h + y.max(0.0)),
            Corner::TopRight => (w - x.min(0.0), h + y.max(0.0)),
            Corner::BottomLeft => (w + x.max(0.0), h - y.min(0.0)),
            Corner::BottomRight => (w - x.min(0.0), h - y.min(0.0)),
        };
        let (ox, oy) = match CORNERS[self.corner].0 {
            Corner::TopLeft => (x.min(0.0), y.min(0.0)),
            Corner::TopRight => (x.max(0.0), y.min(0.0)),
            Corner::BottomLeft => (x.min(0.0), y.max(0.0)),
            Corner::BottomRight => (x.max(0.0), y.max(0.0)),
        };
        let (w2, h2) = (w2.min(sw), h2.min(sh));
        // Shift every shape by the offset the corner box leaves out.
        if ox != 0.0 || oy != 0.0 {
            for shape in &mut shapes {
                match shape {
                    Shape::Fill(f) => {
                        f.rect.x -= ox;
                        f.rect.y -= oy;
                    }
                    Shape::Text(t) => {
                        t.at.x -= ox;
                        t.at.y -= oy;
                    }
                    _ => {}
                }
            }
        }
        render::set_corner(CORNERS[self.corner].0, w2, h2, &shapes);
    }

    /// The page in Options > Mods.
    fn page(&self) {
        let on = |b: bool| if b { "ON" } else { "OFF" };
        let nudge = |i: usize| {
            let v = NUDGE[i];
            if v == 0.0 {
                "flush".to_owned()
            } else {
                format!("{v:+.0}")
            }
        };
        ui::set_settings(&[
            Widget::Button(ButtonWidget {
                id: CORNER_BUTTON,
                label: format!("Corner: {}", CORNERS[self.corner].2),
            }),
            Widget::Button(ButtonWidget {
                id: NUDGE_X_BUTTON,
                label: format!("Nudge across: {}", nudge(self.nudge_x)),
            }),
            Widget::Button(ButtonWidget {
                id: NUDGE_Y_BUTTON,
                label: format!("Nudge down: {}", nudge(self.nudge_y)),
            }),
            Widget::Button(ButtonWidget {
                id: SPACING_BUTTON,
                label: format!("Line spacing: {:.0}", SPACING[self.spacing]),
            }),
            Widget::Button(ButtonWidget {
                id: PADDING_BUTTON,
                label: format!("Padding: {:.0}", PADDING[self.padding]),
            }),
            Widget::Button(ButtonWidget {
                id: COORDS_BUTTON,
                label: format!("Coordinates: {}", on(self.coords)),
            }),
            Widget::Button(ButtonWidget {
                id: TIME_BUTTON,
                label: format!("Time of day: {}", on(self.time)),
            }),
            Widget::Button(ButtonWidget {
                id: FPS_BUTTON,
                label: format!("Frame rate: {}", on(self.fps)),
            }),
        ]);
    }
}

impl Mod for Hud {
    fn init() -> Result<(Self, Registration), String> {
        let hud = Hud {
            corner: stored_index("corner", 0, CORNERS.len()),
            nudge_x: stored_index("nudge_x", NUDGE_ZERO, NUDGE.len()),
            nudge_y: stored_index("nudge_y", NUDGE_ZERO, NUDGE.len()),
            spacing: stored_index("spacing", 0, SPACING.len()),
            padding: stored_index("padding", 1, PADDING.len()),
            coords: stored_bool("coords", true),
            time: stored_bool("time", true),
            fps: stored_bool("fps", true),
            shown: Vec::new(),
        };
        hud.page();
        Ok((hud, Registration::new().on_tick()))
    }

    fn tick(&mut self, _tick: u64) {
        // The frame rate changes every tick, so redraw each time; the other
        // lines rarely do, and `draw` skips an unchanged panel.
        let player = game::get_player();
        self.shown.clear();
        self.draw(player.as_ref());
    }

    fn ui_select(&mut self, id: u32, _row: u32) {
        match id {
            CORNER_BUTTON => self.corner = (self.corner + 1) % CORNERS.len(),
            NUDGE_X_BUTTON => self.nudge_x = (self.nudge_x + 1) % NUDGE.len(),
            NUDGE_Y_BUTTON => self.nudge_y = (self.nudge_y + 1) % NUDGE.len(),
            SPACING_BUTTON => self.spacing = (self.spacing + 1) % SPACING.len(),
            PADDING_BUTTON => self.padding = (self.padding + 1) % PADDING.len(),
            COORDS_BUTTON => self.coords = !self.coords,
            TIME_BUTTON => self.time = !self.time,
            FPS_BUTTON => self.fps = !self.fps,
            _ => return,
        }
        self.keep();
        self.page();
        // Draw at once, so the player sees the panel move while the page is
        // still open rather than after closing it.
        let player = game::get_player();
        self.shown.clear();
        self.draw(player.as_ref());
    }

    fn ui_settings_opened(&mut self) {
        self.page();
    }
}

horizon_mod_sdk::export_mod!(Hud);

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn facing_follows_vanilla_yaw() {
        assert_eq!(facing(0.0), "South (+Z)");
        assert_eq!(facing(90.0), "West (-X)");
        assert_eq!(facing(-180.0), "North (-Z)");
        assert_eq!(facing(-90.0), "East (+X)");
    }

    #[test]
    fn day_time_reads_as_a_clock() {
        let at = |day_time| {
            time_of_day(&Clock {
                game_time: 0,
                day_time,
            })
        };
        assert_eq!(at(0), "Day 1, 06:00");
        assert_eq!(at(18000), "Day 1, 00:00");
        assert_eq!(at(24000 * 2 + 8083), "Day 3, 14:04");
    }

    #[test]
    fn the_nudge_table_has_a_flush_entry() {
        assert_eq!(NUDGE[NUDGE_ZERO], 0.0);
        assert!(NUDGE.iter().any(|v| *v < 0.0), "must reach inwards");
        assert!(NUDGE.iter().any(|v| *v > 0.0), "must reach outwards");
    }

    #[test]
    fn the_panel_grows_with_its_lines() {
        // Three lines at the default spacing and padding.
        let (spacing, padding) = (SPACING[0], PADDING[1]);
        let h = spacing * 2.0 + LINE + padding * 2.0;
        assert!(h > LINE * 3.0, "the panel holds three lines: {h}");
        // A wider spacing makes a taller panel for the same lines.
        let taller = SPACING[5] * 2.0 + LINE + padding * 2.0;
        assert!(taller > h);
    }
}
