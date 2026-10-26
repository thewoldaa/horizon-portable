//! Homes and teleport-back for Horizon.
//!
//! Three commands, all built from vanilla `/tp`, so they need cheats:
//!
//! - `/sethome` remembers where you stand, kept in the mod's storage so it
//!   survives a restart;
//! - `/home` teleports you back to it;
//! - `/back` returns you to where you were before your last `/home`.
//!
//! `/home` and `/back` swap places, so the pair is a round trip: go home,
//! then `/back` returns to where you were, and `/back` again goes home.
//!
//! There is no `/spawn`: vanilla has no command that teleports to the world
//! spawn point, and this mod will not guess coordinates. Use `/sethome` at
//! spawn if that is where you want to return.
use horizon_mod_sdk::{
    Mod, Registration, chat, command::run,
    game::{self, Player},
    storage,
};

/// A place the player can travel to, as `/tp` wants it.
#[derive(Clone, Debug, PartialEq)]
struct Spot {
    x: f64,
    y: f64,
    z: f64,
    dimension: String,
}

impl Spot {
    fn of(p: &Player) -> Spot {
        Spot {
            x: p.x,
            y: p.y,
            z: p.z,
            dimension: p.dimension.clone(),
        }
    }

    /// `minecraft:the_nether` -> `the_nether`, for the chat line.
    fn dimension_name(&self) -> &str {
        self.dimension
            .strip_prefix("minecraft:")
            .unwrap_or(&self.dimension)
    }

    /// `/tp` takes three decimals; more would be noise.
    fn to_command(&self) -> String {
        format!(
            "execute in {} run tp @s {:.3} {:.3} {:.3}",
            self.dimension, self.x, self.y, self.z
        )
    }

    /// The one-line form kept in storage: `dimension x y z`.
    fn encode(&self) -> String {
        format!("{} {} {} {}", self.dimension, self.x, self.y, self.z)
    }

    fn decode(text: &str) -> Option<Spot> {
        let mut parts = text.split_whitespace();
        let dimension = parts.next()?.to_owned();
        let x = parts.next()?.parse().ok()?;
        let y = parts.next()?.parse().ok()?;
        let z = parts.next()?.parse().ok()?;
        // A trailing token means the line is not one this mod wrote.
        if parts.next().is_some() {
            return None;
        }
        Some(Spot {
            x,
            y,
            z,
            dimension,
        })
    }

    /// `123, 64, -45 in overworld`
    fn describe(&self) -> String {
        format!(
            "{:.0}, {:.0}, {:.0} in {}",
            self.x.floor(),
            self.y.floor(),
            self.z.floor(),
            self.dimension_name()
        )
    }
}

/// Storage keys, in the mod's own folder.
const HOME: &str = "home";
const BACK: &str = "back";

fn load(key: &str) -> Option<Spot> {
    storage::get(key)
        .and_then(|b| String::from_utf8(b).ok())
        .and_then(|t| Spot::decode(t.trim()))
}

fn save(key: &str, spot: &Spot) {
    if let Err(e) = storage::set(key, spot.encode().as_bytes()) {
        // Storage is a convenience: losing it costs the player a home, not
        // the session, so say so in the log and carry on.
        horizon_mod_sdk::warn(&format!("could not keep {key}: {e}"));
    }
}

struct Homes {
    /// Where the player was before the last teleport this mod made.
    back: Option<Spot>,
}

impl Homes {
    /// Teleports to `to`, remembering where the player stood.
    fn go(&mut self, p: &Player, to: &Spot) {
        let from = Spot::of(p);
        save(BACK, &from);
        self.back = Some(from);
        run(&to.to_command());
    }
}

impl Mod for Homes {
    fn init() -> Result<(Self, Registration), String> {
        let hooks = Registration::new()
            .command("sethome")
            .command("home")
            .command("back");
        Ok((Homes { back: load(BACK) }, hooks))
    }

    fn command(&mut self, name: &str, _args: &str) -> Result<Option<String>, String> {
        let player = game::get_player().ok_or("Not in a world")?;
        match name {
            "sethome" => {
                let spot = Spot::of(&player);
                save(HOME, &spot);
                chat::show(&format!("Home set to {}", spot.describe()));
                Ok(None)
            }
            "home" => {
                let home =
                    load(HOME).ok_or("No home yet: stand where you want it and run /sethome")?;
                self.go(&player, &home);
                Ok(Some(format!("Teleported home, to {}", home.describe())))
            }
            _ => {
                let back = self
                    .back
                    .clone()
                    .ok_or("Nothing to go back to yet: /home first")?;
                // Swapping makes the pair a round trip.
                let here = Spot::of(&player);
                save(BACK, &here);
                self.back = Some(here);
                run(&back.to_command());
                Ok(Some(format!("Teleported back, to {}", back.describe())))
            }
        }
    }
}

horizon_mod_sdk::export_mod!(Homes);

#[cfg(test)]
mod tests {
    use super::*;

    fn spot() -> Spot {
        Spot {
            x: 12.5,
            y: 64.0,
            z: -30.25,
            dimension: "minecraft:overworld".into(),
        }
    }

    #[test]
    fn a_spot_survives_storage() {
        assert_eq!(Spot::decode(&spot().encode()), Some(spot()));
    }

    #[test]
    fn a_broken_line_is_no_spot() {
        assert_eq!(Spot::decode(""), None);
        assert_eq!(Spot::decode("minecraft:overworld 1 2"), None);
        assert_eq!(Spot::decode("minecraft:overworld a b c"), None);
        assert_eq!(Spot::decode("minecraft:overworld 1 2 3 4"), None);
    }

    #[test]
    fn the_command_names_the_dimension() {
        assert_eq!(
            spot().to_command(),
            "execute in minecraft:overworld run tp @s 12.500 64.000 -30.250"
        );
    }

    #[test]
    fn the_description_drops_the_namespace() {
        assert_eq!(spot().describe(), "12, 64, -31 in overworld");
    }

    #[test]
    fn a_nether_home_keeps_its_dimension() {
        let nether = Spot {
            dimension: "minecraft:the_nether".into(),
            ..spot()
        };
        assert_eq!(Spot::decode(&nether.encode()), Some(nether.clone()));
        assert!(nether.to_command().contains("minecraft:the_nether"));
        assert_eq!(nether.dimension_name(), "the_nether");
    }
}
