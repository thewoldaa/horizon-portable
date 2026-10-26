//! Night vision that belongs to this client alone.
//!
//! Vanilla's night vision is a status effect: the server owns it, so it
//! needs cheats in a single-player world and an operator on a server. That
//! makes it useless in the two places a player most wants it — a hardcore
//! world, where cheats are off by definition, and somebody else's server,
//! where they are not op. This mod instead brightens the client's own
//! lightmap (`render::set_brightness`), which reads no game state and asks
//! no server. Nothing is sent to anyone: other players see the world
//! normally, and the world's difficulty is untouched.
//!
//! Toggle it with a key (N by default; the player can rebind it on this
//! mod's page in Options > Mods) or from that page's button. The choice is
//! kept in the mod's storage, so it comes back on the next launch.
use horizon_mod_sdk::{
    Mod, Registration,
    input::{self, Event},
    render, storage,
    ui::{self, ButtonWidget, Widget},
};

/// The key's name for `register-key`.
const KEY: &str = "night_vision";

/// Settings page buttons.
const TOGGLE_BUTTON: u32 = 1;
const LEVEL_BUTTON: u32 = 2;

/// The brightness levels the button cycles through. The first is the game's
/// own light, the last is every block lit as if at noon; 0.6 is roughly what
/// a night vision potion looks like, so it is the default.
const LEVELS: [f32; 5] = [0.3, 0.45, 0.6, 0.8, 1.0];
const DEFAULT_LEVEL: usize = 2;

struct NightVision {
    on: bool,
    /// Index into `LEVELS`.
    level: usize,
    /// What the game was last told, so a frame that changes nothing costs
    /// no call.
    shown: Option<f32>,
}

impl NightVision {
    fn brightness(&self) -> f32 {
        if self.on { LEVELS[self.level] } else { 0.0 }
    }

    /// Tells the game the brightness, when it differs from the last one.
    fn show(&mut self) {
        let want = self.brightness();
        if self.shown == Some(want) {
            return;
        }
        render::set_brightness(want);
        self.shown = Some(want);
    }

    fn page(&self) {
        let on = if self.on { "ON" } else { "OFF" };
        ui::set_settings(&[
            Widget::Button(ButtonWidget {
                id: TOGGLE_BUTTON,
                label: format!("Night vision: {on}"),
            }),
            Widget::Button(ButtonWidget {
                id: LEVEL_BUTTON,
                label: format!("Brightness: {:.0}%", LEVELS[self.level] * 100.0),
            }),
        ]);
    }

    fn save(&self) {
        let flag = if self.on { &b"true"[..] } else { &b"false"[..] };
        let _ = storage::set("on", flag);
        let _ = storage::set("level", self.level.to_string().as_bytes());
    }
}

fn stored(key: &str) -> Option<String> {
    storage::get(key).and_then(|v| String::from_utf8(v).ok())
}

impl Mod for NightVision {
    fn init() -> Result<(Self, Registration), String> {
        input::register_key(KEY, "Night vision", "key.keyboard.n")?;
        let level = stored("level")
            .and_then(|v| v.trim().parse::<usize>().ok())
            .map_or(DEFAULT_LEVEL, |v| v.min(LEVELS.len() - 1));
        // Off until the player asks for it: a mod that brightens the world
        // the moment it is installed would be a surprise.
        let on = stored("on").is_some_and(|v| v.trim() == "true");
        let mut nv = NightVision {
            on,
            level,
            shown: None,
        };
        nv.page();
        // Apply what was kept, so a player who left it on gets it back at
        // launch rather than after the first keypress.
        nv.show();
        Ok((nv, Registration::new().on_frame()))
    }

    fn frame(&mut self, _seconds: f32) {
        let mut changed = false;
        for event in input::poll() {
            if let Event::KeyDown(k) = event
                && k == KEY
            {
                self.on = !self.on;
                changed = true;
            }
        }
        if changed {
            self.show();
            self.save();
            self.page();
        }
    }

    fn ui_select(&mut self, id: u32, _row: u32) {
        match id {
            TOGGLE_BUTTON => self.on = !self.on,
            LEVEL_BUTTON => self.level = (self.level + 1) % LEVELS.len(),
            _ => return,
        }
        self.show();
        self.save();
        self.page();
    }

    fn ui_settings_opened(&mut self) {
        self.page();
    }
}

horizon_mod_sdk::export_mod!(NightVision);
