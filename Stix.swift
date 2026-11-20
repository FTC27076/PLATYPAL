// Stix — an acrobatic stick figure that lives on your Mac desktop.
// (A sibling of Platypal: same app, different character. See Platypal.swift for the platypus.)
//
// Build:  ./build-stix.sh   (needs Xcode Command Line Tools: `xcode-select --install`)
// Run:    open Stix.app
//
// Controls
//   • Click        → poke him
//   • Double-click → backflip
//   • Drag         → pick him up; let go mid-swing to throw him (he may wall-kick or superhero-land)
//   • Right-click  → menu (also in the menu bar, figure icon)
//   • Leave the cursor resting near his head → he throws a punch-punch-kick combo at it
//   • Swipe the cursor through him fast → he gets knocked flying (or flips out of the way)
//   • Drop him onto a desktop folder icon → he falls into it
//   • He sometimes hides behind app windows that reach the Dock, then peeks out

import Cocoa

// MARK: - Tunables

let kWinW: CGFloat = 320
let kWinH: CGFloat = 330
let kFootY: CGFloat = 50          // where his feet sit inside the (transparent) window
let kGravity: CGFloat = 2200      // px / s²
let kEdge: CGFloat = 70           // how close to the screen edge he walks
let kAwayTime: Double = 180       // seconds of no mouse movement before he dozes off

enum Palette {
    static let body      = NSColor(srgbRed: 0.19, green: 0.84, blue: 0.78, alpha: 1) // turquoise
    static let bodyShade = NSColor(srgbRed: 0.12, green: 0.68, blue: 0.64, alpha: 1)
    static let belly     = NSColor(srgbRed: 0.74, green: 0.97, blue: 0.93, alpha: 1)
    static let tail      = NSColor(srgbRed: 0.09, green: 0.55, blue: 0.53, alpha: 1)
    static let bill      = NSColor(srgbRed: 0.13, green: 0.29, blue: 0.35, alpha: 1)
    static let billLight = NSColor(srgbRed: 0.21, green: 0.41, blue: 0.48, alpha: 1)
    static let outline   = NSColor(srgbRed: 0.04, green: 0.22, blue: 0.25, alpha: 1)
    static let blush     = NSColor(srgbRed: 1.00, green: 0.52, blue: 0.60, alpha: 0.55)
    static let star      = NSColor(srgbRed: 1.00, green: 0.82, blue: 0.25, alpha: 1)
    static let ink       = NSColor(white: 0.07, alpha: 1)                              // the stick figure
    static let inkBack   = NSColor(white: 0.30, alpha: 1)                              // his far-side limbs
    static let scarf     = NSColor(srgbRed: 0.93, green: 0.27, blue: 0.30, alpha: 1)
}

extension Array {
    var pick: Element { self[Int.random(in: 0..<count)] }
}

// MARK: - Things he says

enum Lines {
    static let chatter = [
        "I'm made of six lines and pure attitude.",
        "Fun fact: I have no bones. Just very confident lines.",
        "Someone has to guard this Dock. That someone is me.",
        "Want to see a backflip? Too late, I'm already thinking about it.",
        "I've been practising my kicks. Mostly on air.",
        "That cursor keeps looking at me funny.",
        "If I stand very still, do I look like a letter? Maybe a K.",
        "I trained for years for this. Well, frames.",
        "Is it snack time? It feels like snack time.",
        "You've been at it a while. Stretch break?",
        "Remember to drink some water!",
        "Have you saved your work recently? Just asking.",
        "*hums an epic fight theme*",
        "Hey. You're doing great.",
        "Parkour is just walking with extra steps.",
        "My scarf is aerodynamic. I checked.",
    ]
    static let poke    = ["Hey!", "Hi there!", "That tickles!", "What's up?", "*happy chirp*", "Yes? Hello?", "Present!"]
    static let held    = ["Wheee!", "Put me doooown!", "I can see my house from here!", "Hey! Hands off! ...okay, fine."]
    static let landed  = ["Nailed it.", "I meant to do that.", "10/10, would fly again.", "Ta-da!"]
    static let dizzy   = ["Ow... my bill.", "Seeing stars...", "Who threw that?! Oh. You.", "The room is spinning..."]
    static let wall    = ["Oof!", "Wall!", "Ack!"]
    static let flip    = ["Hyah!", "Parkour!", "Backflip!", "Watch this!"]
    static let dance   = ["♪ Dance break! ♪", "Feel the rhythm!", "♪ Platy-party ♪"]
    static let sleep   = ["Just resting my eyes...", "Nap time.", "Five more minutes..."]
    static let wake    = ["*yawn* What'd I miss?", "I'm up! Totally wasn't sleeping.", "*stretch*"]
    static let rudeWake = ["Huh?! I'm up! I'm up!", "Wha—? Oh. Hi."]
    static let chase   = ["Ooh, what's that?", "Gonna get that cursor!", "Come back here!"]
    static let caught  = ["Got it! ...now what?", "Hello, little arrow.", "Found you."]
    static let welcomeBack = ["Oh! You're back!", "Welcome back!", "Missed you. Kinda."]
    static let kick    = ["GOOOAL!", "Hyah!", "Bend it like a stick figure!", "Kick!", "And he shoots..."]
    static let header  = ["Header!", "Ow, my head. Worth it.", "Bonk!"]
    static let ballHit = ["Oof!", "Hey!", "Watch it!"]
    static let boing   = ["Boing!", "Wheee!", "Higher!", "Boing boing!", "Look, I'm flying!"]
    static let newToy  = ["Ooh, a toy!", "For me?!", "Best day ever!"]
    static let agent   = [
        "Agent Stix, reporting for duty.",
        "*whispers* The cursor is a suspect.",
        "Mission status: snacks not yet located.",
        "I've seen things. Mostly spreadsheets.",
        "This message will self-destruct. Kidding. I'm a stick figure.",
        "Code name: Turquoise Shadow.",
        "*taps earpiece* Copy that, HQ.",
    ]
    static let fight   = ["Hi-yah!", "Take that, cursor!", "Hyah! Hyah!", "You want some?!", "Pow!"]
    static let heroLanding = ["Superhero landing!", "*dramatic pose*", "Nailed it.", "Ta-da!"]
    static let knocked = ["Whoa!", "Hey! Watch where you're pointing!", "Cheap shot!"]
    static let dodge   = ["Too slow!", "Missed me!", "Nope!"]
    static let rustle  = ["*rustle rustle*", "*muffled* ...so many files...", "*thump* Ow.", "*echo* Hellooo?"]

    static func folderFinding(folder: String, items: [String]) -> String {
        guard let item = items.randomElement() else {
            return "\"\(folder)\" is empty. Just me and the echo."
        }
        let n = items.count
        let things = n == 1 ? "1 thing" : "\(n) things"
        return [
            "Found \(things) in \"\(folder)\". \"\(item)\" looks interesting.",
            "\"\(item)\"? Bold choice. I didn't touch it, promise.",
            "Cozy in \"\(folder)\". \(things), zero snacks.",
        ].pick
    }

    static func greeting() -> String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12:  return "Good morning! Coffee first, then greatness."
        case 12..<18: return "Good afternoon! I'm here to help. By walking around."
        case 18..<23: return "Good evening! Mind if I hang out?"
        default:      return "It's late! I'll keep you company."
        }
    }

    static func randomChatter(agent: Bool = false) -> String {
        if agent && Bool.random() { return Lines.agent.pick }
        let hour = Calendar.current.component(.hour, from: Date())
        if Double.random(in: 0..<1) < 0.2 {
            switch hour {
            case 5..<11:  return "Morning brain is loading... please wait."
            case 13..<16: return "Afternoon slump? I believe in you."
            case 18..<23: return "Evening already? Time flies when you're having fights with cursors."
            case 23..<24, 0..<5: return "It's pretty late... bed soon, maybe?"
            default: break
            }
        }
        return chatter.pick
    }
}

// MARK: - Other apps' windows (for hiding behind)

struct OtherWindow {
    let number: Int
    let frame: CGRect      // Cocoa coordinates (origin bottom-left of the main screen)
}

@MainActor
enum Desktop {
    /// Normal app windows currently on screen, front to back. Window bounds don't need
    /// Screen Recording permission (only titles do, and we don't read those).
    static func windows() -> [OtherWindow] {
        guard let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
                as? [[String: Any]] else { return [] }
        let myPID = Int(ProcessInfo.processInfo.processIdentifier)
        let mainH = NSScreen.screens.first?.frame.height ?? 0
        return info.compactMap { w in
            guard (w[kCGWindowLayer as String] as? Int) == 0,
                  (w[kCGWindowOwnerPID as String] as? Int) != myPID,
                  ((w[kCGWindowAlpha as String] as? Double) ?? 1) > 0.1,
                  let number = w[kCGWindowNumber as String] as? Int,
                  let dict = w[kCGWindowBounds as String] as? NSDictionary,
                  let r = CGRect(dictionaryRepresentation: dict as CFDictionary)
            else { return nil }
            return OtherWindow(number: number, frame: CGRect(x: r.minX, y: mainH - r.maxY, width: r.width, height: r.height))
        }
    }

    static func window(number: Int) -> OtherWindow? {
        windows().first { $0.number == number }
    }
}

// MARK: - Desktop folder icons (via Finder AppleScript)

struct DesktopFolder {
    let name: String
    let point: CGPoint     // icon centre, Cocoa coordinates
}

/// If he lands a bit off from the icons on your Mac, nudge this (Cocoa points; +y is up).
let kIconOffset = CGVector(dx: 10, dy: 10)
let kDropHalfWidth: CGFloat = 56   // how far left/right of the icon centre still counts
let kMaxDropSpeed: CGFloat = 1200  // faster than this is a throw, not a drop

enum FinderBridge {
    /// Runs AppleScript through osascript off the main thread. The first run makes macOS ask
    /// "Stix wants to control Finder". If you say no, the folder trick just won't happen.
    /// The last error osascript reported (nil if the last run succeeded). Shown in debug mode.
    @MainActor static var lastError: String?
    /// Finder's raw answer to the last folder query, for debugging.
    @MainActor static var lastFolderReply: String?

    static func run(_ script: String, completion: @escaping @Sendable @MainActor (String?) -> Void) {
        DispatchQueue.global(qos: .utility).async {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            proc.arguments = ["-e", script]
            let out = Pipe(), err = Pipe()
            proc.standardOutput = out
            proc.standardError = err
            var result: String?
            var error: String?
            do {
                try proc.run()
                let data = out.fileHandleForReading.readDataToEndOfFile()
                let errData = err.fileHandleForReading.readDataToEndOfFile()
                proc.waitUntilExit()
                if proc.terminationStatus == 0 {
                    result = String(data: data, encoding: .utf8)
                } else {
                    error = String(data: errData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
                    if error?.isEmpty ?? true { error = "osascript exited with status \(proc.terminationStatus)" }
                }
            } catch let e {
                error = "Couldn't launch osascript: \(e.localizedDescription)"
            }
            let r = result, e = error
            NSLog("Stix osascript → %@", e.map { "ERROR: \($0)" } ?? "OK:\n\(r ?? "")")
            Task { @MainActor in
                lastError = e
                completion(r)
            }
        }
    }

    static func desktopFolders(_ completion: @escaping @Sendable @MainActor ([DesktopFolder]) -> Void) {
        let script = """
        -- Ask for all names and all positions in one go. Looping over "every folder of desktop"
        -- one by one fails on some Macs with -1728 ("Can't get item 1 of desktop").
        tell application "Finder"
            set theNames to name of every folder of desktop
            set thePositions to desktop position of every folder of desktop
        end tell
        set out to ""
        repeat with i from 1 to count of theNames
            set p to item i of thePositions
            set out to out & (item i of theNames) & tab & (item 1 of p) & tab & (item 2 of p) & linefeed
        end repeat
        return out
        """
        run(script) { text in
            lastFolderReply = text
            let mainH = NSScreen.screens.first?.frame.height ?? 0
            // Be forgiving about line endings (LF, CR or CRLF) and stray spaces around numbers.
            let lines = (text ?? "").components(separatedBy: .newlines)
            // Some locales write numbers like "123,0"
            func number(_ s: String) -> Double? {
                Double(s.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "."))
            }
            let folders: [DesktopFolder] = lines.compactMap { line in
                let parts = line.components(separatedBy: "\t")
                guard parts.count >= 3,
                      let x = number(parts[parts.count - 2]),
                      let y = number(parts[parts.count - 1])
                else { return nil }
                let name = parts.dropLast(2).joined(separator: "\t")
                // Finder uses top-left-origin coordinates; flip to Cocoa's bottom-left origin.
                return DesktopFolder(name: name,
                                     point: CGPoint(x: x + kIconOffset.dx, y: mainH - y + kIconOffset.dy))
            }
            completion(folders)
        }
    }

    static func contents(ofDesktopFolder name: String, _ completion: @escaping @Sendable @MainActor ([String]?) -> Void) {
        let escaped = name.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        tell application "Finder"
            set theNames to name of every item of folder "\(escaped)" of desktop
        end tell
        set out to ""
        repeat with n in theNames
            set out to out & (contents of n) & linefeed
        end repeat
        return out
        """
        run(script) { text in
            completion(text.map { $0.split(separator: "\n").map(String.init) })
        }
    }
}

// MARK: - The stick figure (state + behaviour)

enum Activity: Equatable {
    case idle, walk, run, chase, stare, sleep, dance, boop, dizzy, held, airborne, hide, folder, fetch, trampoline, land, trick
}

enum HidePhase { case approach, sneak, hidden, peek }

enum TrickKind { case none, handstand, shadowbox, cartwheel, frontflip }

enum Hat: String, CaseIterable {
    case none, party, top, crown, propeller, beanie
    var title: String {
        switch self {
        case .none: return "No Hat"
        case .party: return "Party Hat"
        case .top: return "Top Hat"
        case .crown: return "Crown"
        case .propeller: return "Propeller Cap"
        case .beanie: return "Beanie"
        }
    }
    var reaction: String {
        switch self {
        case .none: return "Hat-free and fancy-free."
        case .party: return "It's a party! Who's invited? Me."
        case .top: return "Most distinguished. Indubitably."
        case .crown: return "Bow before King Stix!"
        case .propeller: return "If I spin fast enough, can I fly?"
        case .beanie: return "Cozy."
        }
    }
}

enum EyeStyle { case open, closed, happy, dizzy, wide }

@MainActor
final class Pet {
    // Position is the point between his feet, in global screen coordinates.
    var pos = CGPoint.zero
    var vel = CGVector.zero
    var facing: CGFloat = 1
    var onGround = false

    var activity: Activity = .airborne
    var activityTime: Double = 0
    var activityDuration: Double = 2
    var targetX: CGFloat = 0
    private var lastBeat = -1

    // Animation
    var time: Double = 0
    var spin: CGFloat = 0
    var spinSpeed: CGFloat = 0
    var squash: CGFloat = 1
    var walkPhase: CGFloat = 0
    var heldSwingTarget: CGFloat = 0
    var blink: Double = 0
    private var nextBlink: Double = 3
    var happyTime: Double = 0
    var look = CGVector(dx: 1, dy: 0)
    var mouthOpen: CGFloat = 0
    var shrink: CGFloat = 1          // < 1 while he's disappearing into / popping out of a folder
    var stepping = false             // legs walking this frame

    // Hiding behind windows. AppDelegate watches `hideBehind` and re-layers the window.
    var hideBehind: Int?
    private var hidePhase = HidePhase.approach
    private var hideWin: OtherWindow?
    private var hideFromLeft = true
    private var hideCheck: Double = 0
    private var peekTime: Double = 0

    // Desktop folders
    private var folders: [DesktopFolder] = []
    private var targetFolder: DesktopFolder?
    private var currentFolder: DesktopFolder?
    private var folderFrom = CGPoint.zero
    private var folderFinding: String?
    private var saidRustle = false

    // Speech
    var speech: String?
    var speechTime: Double = 0
    var speechDuration: Double = 0
    var nextChatter: Double = 30
    var chatterEnabled = true

    // Dress-up and toys
    var hat: Hat = .none
    var agent = false
    weak var ball: Prop?
    weak var trampoline: Prop?
    private var kicksLeft = 0
    private var trampBounces = 0
    private var trampTarget = 0
    private var trampJumping = false
    private var ballHitCooldown: Double = 0

    // Stick-figure moves
    var trickKind = TrickKind.none
    var kickTime: Double = 0          // > 0 while his leg swings into the ball
    private var cursorSpeed: CGFloat = 0
    private var cursorDX: CGFloat = 0
    private var knockCooldown: Double = 0

    // Bookkeeping
    private var wasThrown = false
    private var willBeDizzy = false
    private var bounces = 0
    private var hasGreeted = false
    private var cursorIdle: Double = 0
    private var userIdle: Double = 0
    private var lastMouse = CGPoint.zero
    private var screen: NSScreen?

    /// Usable area of whichever screen he's on (excludes menu bar & Dock).
    var area: CGRect {
        let probe = CGPoint(x: pos.x, y: pos.y + 20)
        if let s = NSScreen.screens.first(where: { $0.frame.contains(probe) }) { screen = s }
        return (screen ?? NSScreen.main ?? NSScreen.screens[0]).visibleFrame
    }

    var eyes: EyeStyle {
        switch activity {
        case .sleep: return .closed
        case .dizzy: return .dizzy
        case .held, .chase, .folder: return .wide
        case .trampoline where !onGround, .fetch where happyTime > 0: return .happy
        case .dance, .boop: return .happy
        case .hide where hidePhase == .sneak: return .happy
        default:
            if happyTime > 0 { return .happy }
            return blink > 0 ? .closed : .open
        }
    }

    // MARK: Actions

    func set(_ a: Activity, duration: Double = 2) {
        activity = a
        activityTime = 0
        activityDuration = duration
        lastBeat = -1
        trickKind = .none
        if a != .hide { hideBehind = nil }
    }

    func say(_ text: String, duration: Double? = nil) {
        speech = text
        speechTime = 0
        speechDuration = duration ?? max(2.8, Double(text.count) * 0.075)
        nextChatter = Double.random(in: 35...90)
    }

    private func jump(_ vy: CGFloat, vx: CGFloat = 0, flip: Bool = false) {
        guard onGround else { return }
        onGround = false
        vel = CGVector(dx: vx, dy: vy)
        squash = 1.15
        spinSpeed = flip ? 2 * .pi / (2 * vy / kGravity) : 0   // exactly one turn per jump
        wasThrown = false
        bounces = 0
    }

    var canAct: Bool { onGround && activity != .held }

    func backflip() {
        guard canAct else { return }
        set(.airborne)
        jump(820, flip: true)
        if Bool.random() { say(Lines.flip.pick, duration: 1.5) }
    }

    func trick() {
        guard canAct else { return }
        switch Int.random(in: 0..<4) {
        case 0:
            set(.trick, duration: 3.5)
            trickKind = .handstand
            say(["Look, no feet!", "Handstand!"].pick, duration: 1.6)
        case 1:
            set(.trick, duration: 0.22 * 14)
            trickKind = .shadowbox
            say(Lines.fight.pick, duration: 1.4)
        case 2:
            set(.airborne)
            jump(560, vx: facing * 260, flip: true)
            spinSpeed = -spinSpeed                     // cartwheel rolls forward
            trickKind = .cartwheel
        default:
            set(.airborne)
            jump(820, flip: true)
            spinSpeed = -spinSpeed                     // front flip
            trickKind = .frontflip
            say("Front flip!", duration: 1.3)
        }
    }

    func hop() {
        guard canAct else { return }
        set(.airborne)
        jump(480, vx: facing * 140)
    }

    func dance() {
        guard canAct else { return }
        set(.dance, duration: 5)
        say(Lines.dance.pick, duration: 2.5)
    }

    func nap(duration: Double = .random(in: 12...30)) {
        guard canAct else { return }
        set(.sleep, duration: duration)
        say(Lines.sleep.pick, duration: 2.5)
    }

    func chase() {
        guard canAct else { return }
        set(.chase, duration: 6)
        say(Lines.chase.pick, duration: 2)
    }

    func come(to x: CGFloat) {
        guard canAct else { return }
        let a = area
        targetX = min(max(x, a.minX + kEdge), a.maxX - kEdge)
        set(.run, duration: 20)
        say("Coming!", duration: 1.5)
    }

    func saySomething() { say(Lines.randomChatter(agent: agent)) }

    // MARK: Toys

    func playBall() {
        guard canAct, let b = ball, !b.held else { return }
        kicksLeft = Int.random(in: 2...4)
        set(.fetch, duration: 15)
    }

    func playTrampoline() {
        guard canAct, let t = trampoline, !t.held, t.onGround else { return }
        trampJumping = false
        set(.trampoline, duration: 20)
    }

    func gotHitByBall(speed: CGFloat, fromAbove: Bool) {
        guard ballHitCooldown <= 0, speed > 250 else { return }
        ballHitCooldown = 1.5
        squash = 0.8
        if fromAbove { if Bool.random() { say(Lines.header.pick, duration: 1.5) } }
        else if speed > 700 { say(Lines.ballHit.pick, duration: 1.2) }
    }

    /// Feet just crossed the trampoline mat on the way down.
    private func bounceOnTrampoline(_ t: Prop) {
        let impact = -vel.dy
        pos.y = t.matY
        t.dip = min(1, 0.4 + impact / 2000)
        squash = 0.7
        spin = 0
        willBeDizzy = false
        bounces = 0
        if activity == .trampoline && trampBounces < trampTarget {
            trampBounces += 1
            let vy = CGFloat.random(in: 950...1250)
            vel = CGVector(dx: (t.pos.x - pos.x) * 2, dy: vy)          // drift back to the middle
            let flip = trampBounces > 1 && Double.random(in: 0..<1) < 0.45
            spinSpeed = flip ? 2 * .pi / (2 * vy / kGravity) * (Bool.random() ? 1 : -1) : 0
            if Double.random(in: 0..<1) < 0.35 { say(Lines.boing.pick, duration: 1.2) }
        } else if impact > 450 && activity != .trampoline {
            vel.dy = min(1500, impact * 0.8)                           // thrown onto it: boing!
            vel.dx *= 0.8
            spinSpeed *= 0.5
            if Bool.random() { say(Lines.boing.pick, duration: 1.2) }
        } else {
            let dir: CGFloat = pos.x < t.pos.x ? -1 : 1                // hop off the side
            facing = dir
            vel = CGVector(dx: dir * 230, dy: 520)
            spinSpeed = 0
            if activity == .trampoline { set(.airborne) }
        }
    }

    private func updateFetch(dt: Double) {
        let fdt = CGFloat(dt)
        guard let b = ball else { set(.idle); return }
        let a = area
        if b.held || b.pos.y - kBallRadius > a.minY + 60 {
            facing = b.pos.x > pos.x ? 1 : -1                         // watch it fly
        } else {
            let dir: CGFloat = b.pos.x > pos.x ? 1 : -1
            let standX = b.pos.x - dir * 40
            let close = abs(b.pos.x - pos.x) < 62 && b.pos.y - kBallRadius < a.minY + 20
            if close {
                facing = dir
                var kickDir = dir
                if b.pos.x < a.minX + 150 { kickDir = 1 }                // don't kick it into the wall
                if b.pos.x > a.maxX - 150 { kickDir = -1 }
                b.vel = CGVector(dx: kickDir * .random(in: 450...1000), dy: .random(in: 250...750))
                b.dip = 0
                squash = 0.75
                happyTime = 0.8
                ballHitCooldown = 0.6
                kickTime = 0.35
                kicksLeft -= 1
                if Double.random(in: 0..<1) < 0.5 { say(Lines.kick.pick, duration: 1.4) }
                if kicksLeft <= 0 { set(.idle, duration: 1.5); return }
            } else {
                _ = walk(toward: standX, speed: 230, dt: fdt)
            }
        }
        if activityTime > activityDuration { set(.idle, duration: 1.5) }
    }

    private func updateTrampolineApproach(dt: Double) {
        guard let t = trampoline, !t.held, t.onGround else { set(.idle); return }
        if trampJumping { set(.idle); return }        // landed on the floor instead: missed
        if walk(toward: t.pos.x, speed: 150, dt: CGFloat(dt)) {
            trampJumping = true
            trampBounces = 0
            trampTarget = .random(in: 4...8)
            jump(700)
            say("Here I go!", duration: 1.2)
        }
        if activityTime > activityDuration { set(.idle) }
    }

    // MARK: Hiding behind windows

    /// Picks an app window that reaches down to his floor, walks to its edge, then sneaks behind it.
    @discardableResult
    func tryHide() -> Bool {
        guard canAct else { return false }
        let a = area
        let lo = a.minX + kEdge, hi = a.maxX - kEdge
        let candidates = Desktop.windows().filter {
            $0.frame.minY <= a.minY + 15 && $0.frame.maxY >= a.minY + 100 &&
            $0.frame.width >= 300 && $0.frame.intersects(a)
        }
        for w in candidates.shuffled() {
            let leftOut = w.frame.minX - 60, rightOut = w.frame.maxX + 60
            let leftOK = leftOut >= lo, rightOK = rightOut <= hi
            let fromLeft: Bool
            if leftOK && (pos.x < w.frame.midX || !rightOK) { fromLeft = true }
            else if rightOK { fromLeft = false }
            else { continue }
            hideWin = w
            hideFromLeft = fromLeft
            hidePhase = .approach
            targetX = fromLeft ? leftOut : rightOut
            set(.hide, duration: .infinity)
            return true
        }
        return false
    }

    private func stillCovered(_ w: OtherWindow) -> OtherWindow? {
        guard let fresh = Desktop.window(number: w.number),
              fresh.frame.minY <= area.minY + 15, fresh.frame.maxY >= area.minY + 100 else { return nil }
        return fresh
    }

    private func abandonHiding() {
        set(.idle, duration: 1.5)
        say("Hey! Who moved my hiding spot?", duration: 2.2)
    }

    /// Steps toward x. Returns true on arrival.
    private func walk(toward x: CGFloat, speed: CGFloat, dt: CGFloat) -> Bool {
        let d = x - pos.x
        if abs(d) <= speed * dt + 1 { pos.x = x; return true }
        facing = d > 0 ? 1 : -1
        pos.x += facing * speed * dt
        walkPhase += dt * max(8, speed / 9)
        stepping = true
        return false
    }

    private func updateHide(dt: Double) {
        let fdt = CGFloat(dt)
        guard var w = hideWin else { set(.idle); return }

        if hidePhase != .approach {
            hideCheck -= dt
            if hideCheck <= 0 {
                hideCheck = 0.5
                guard let fresh = stillCovered(w) else { abandonHiding(); return }
                w = fresh
                hideWin = fresh
            }
        }
        let a = area
        let f = w.frame
        let inside = hideFromLeft ? min(f.minX + 130, f.midX) : max(f.maxX - 130, f.midX)
        let insideX = min(max(inside, a.minX + kEdge), a.maxX - kEdge)

        switch hidePhase {
        case .approach:
            if walk(toward: targetX, speed: 110, dt: fdt) {
                guard let fresh = stillCovered(w) else { set(.idle); return }
                hideWin = fresh
                hidePhase = .sneak
                hideBehind = fresh.number
                hideCheck = 0.5
                say("Shh... hiding.", duration: 1.6)
            }
            if activityTime > 25 { set(.idle) }   // couldn't get there
        case .sneak:
            if walk(toward: insideX, speed: 60, dt: fdt) {
                hidePhase = .hidden
                activityTime = 0
                activityDuration = .random(in: 4...9)
            }
        case .hidden:
            if activityTime > activityDuration {
                hidePhase = .peek
                peekTime = 0
            }
        case .peek:
            // Stop with just his head poking out past the window edge.
            let peekX = hideFromLeft ? f.minX + 6 : f.maxX - 6
            if walk(toward: peekX, speed: 60, dt: fdt) {
                facing = hideFromLeft ? -1 : 1
                peekTime += dt
                if peekTime > 1.6 {
                    set(.airborne)                     // also brings him back in front
                    jump(450, vx: facing * 160)
                    say("Peekaboo!", duration: 1.8)
                }
            }
        }
    }

    // MARK: Desktop folders

    func refreshFolders(announce: Bool = false) {
        FinderBridge.desktopFolders { [weak self] found in
            guard let self else { return }
            self.folders = found
            if announce { self.say(self.folderStatus(), duration: 6) }
        }
    }

    private func enterFolder(_ f: DesktopFolder) {
        targetFolder = nil
        currentFolder = f
        folderFrom = pos
        folderFinding = nil
        saidRustle = false
        onGround = false
        vel = .zero
        spinSpeed = 0
        set(.folder, duration: .random(in: 6...11))
        say("Wheee—", duration: 1)
        FinderBridge.contents(ofDesktopFolder: f.name) { [weak self] items in
            guard let self, let items else { return }
            self.folderFinding = Lines.folderFinding(folder: f.name, items: items)
        }
    }

    private func exitFolder() {
        currentFolder = nil
        set(.airborne)
        onGround = false
        wasThrown = false
        bounces = 0
        vel = CGVector(dx: facing * 160, dy: 750)
        say(folderFinding ?? "It's dark in there!")
    }

    func poke() {
        guard activity != .held else { return }
        if activity == .sleep {
            set(.idle, duration: 2)
            say(Lines.rudeWake.pick)
        } else {
            happyTime = 1.2
            say(Lines.poke.pick, duration: 2)
        }
        squash = 0.72
    }

    func beginHold() {
        set(.held, duration: .infinity)
        onGround = false
        vel = .zero
        spinSpeed = 0
        targetFolder = nil
        if speech == nil || Bool.random() { say(Lines.held.pick, duration: 2.2) }
        refreshFolders()   // icons may have moved since last time
    }

    func release(velocity v: CGVector) {
        let maxV: CGFloat = 3200
        let speed = hypot(v.dx, v.dy)
        let k = speed > maxV ? maxV / speed : 1
        vel = CGVector(dx: v.dx * k, dy: v.dy * k)
        set(.airborne)
        onGround = false
        wasThrown = speed > 300
        willBeDizzy = false
        bounces = 0
        spinSpeed = wasThrown ? -vel.dx / 150 * facing : 0   // tumble in the direction of travel
        heldSwingTarget = 0

        // Dropped (not thrown) on, just under, or above a desktop folder? He falls into it.
        targetFolder = nil
        lastDropSpeed = speed
        if speed < kMaxDropSpeed, let f = folders.first(where: { Pet.dropZone(for: $0).contains(pos) }) {
            targetFolder = f
            vel = CGVector(dx: 0, dy: min(vel.dy, 0))
            pos.x = f.point.x
            wasThrown = false
            spinSpeed = 0
        }
        if debugFolders { say(dropDiagnosis(speed: speed), duration: 6) }
    }

    // MARK: Folder debugging

    var debugFolders = false
    private(set) var lastDropSpeed: CGFloat = 0
    var knownFolders: [DesktopFolder] { folders }

    /// Where his feet have to be when you let go for him to fall into folder `f`:
    /// up to 75 pt under the icon centre, and anywhere up to 400 pt above it.
    static func dropZone(for f: DesktopFolder) -> CGRect {
        CGRect(x: f.point.x - kDropHalfWidth, y: f.point.y - 75, width: kDropHalfWidth * 2, height: 475)
    }

    /// Plain-English reason why the last drop did or didn't hit a folder.
    private func dropDiagnosis(speed: CGFloat) -> String {
        if let f = targetFolder { return "Debug: going into \"\(f.name)\"!" }
        if folders.isEmpty {
            if let e = FinderBridge.lastError {
                if e.contains("-1743") || e.lowercased().contains("not authorized") {
                    return "Debug: macOS won't let me ask Finder (-1743). See README → Debugging."
                }
                return "Debug: Finder error: \(e.prefix(120))"
            }
            return emptyReason()
        }
        if speed >= kMaxDropSpeed { return "Debug: let go too fast (\(Int(speed)) pt/s). Hold still, then let go." }
        let nearest = folders.min { hypot(pos.x - $0.point.x, pos.y - $0.point.y) < hypot(pos.x - $1.point.x, pos.y - $1.point.y) }!
        let dx = Int(nearest.point.x - pos.x), dy = Int(nearest.point.y - pos.y)
        return "Debug: missed. Nearest is \"\(nearest.name)\": \(abs(dx)) pt \(dx >= 0 ? "right" : "left"), \(abs(dy)) pt \(dy >= 0 ? "above" : "below") my feet."
    }

    /// Finder answered without an error but we got no folders. Was the answer empty, or unreadable?
    private func emptyReason() -> String {
        let raw = (FinderBridge.lastFolderReply ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if FinderBridge.lastFolderReply == nil { return "Debug: Finder hasn't answered yet. Try again in a second." }
        if raw.isEmpty { return "Debug: Finder says there are 0 folders on the desktop. (Stacks on? Folders in a subfolder?)" }
        let shown = raw.prefix(100).replacingOccurrences(of: "\t", with: " ⇥ ")
        return "Debug: Finder replied, but I couldn't read it: \(shown)"
    }

    func folderStatus() -> String {
        if let e = FinderBridge.lastError, folders.isEmpty {
            return e.contains("-1743") ? "Debug: Finder permission is blocked (-1743). See README → Debugging."
                                       : "Debug: Finder error: \(e.prefix(120))"
        }
        if folders.isEmpty { return emptyReason() }
        return "Debug: I see \(folders.count) folder\(folders.count == 1 ? "" : "s"). Red boxes = drop zones."
    }

    private func land(impact: CGFloat) {
        onGround = true
        vel = .zero
        spinSpeed = 0
        squash = max(0.55, 1 - impact / 3000)
        if activity == .airborne {
            if willBeDizzy && Bool.random() {
                set(.dizzy, duration: 2.8)
                say(Lines.dizzy.pick)
            } else if impact > 1250 {
                set(.land, duration: 0.8)
                if wasThrown || Bool.random() { say(Lines.heroLanding.pick, duration: 1.8) }
            } else if wasThrown {
                set(.idle, duration: 1.5)
                if Bool.random() { say(Lines.landed.pick, duration: 2) }
            } else {
                set(.idle, duration: .random(in: 1...2.5))
            }
            if !hasGreeted { hasGreeted = true; say(Lines.greeting(), duration: 4) }
        }
        wasThrown = false
        willBeDizzy = false
    }

    private func bonk() {
        if wasThrown && abs(vel.dx) > 600 && Bool.random() {    // wall kick!
            vel.dy = max(vel.dy, 700)
            vel.dx *= 1.7
            spinSpeed = Bool.random() ? 10 : -10
            say("Parkour!", duration: 1.2)
            return
        }
        if wasThrown && abs(vel.dx) > 900 { say(Lines.wall.pick, duration: 1.2) }
        squash = 0.8
    }

    private func chooseNext() {
        let a = area
        let lo = a.minX + kEdge, hi = a.maxX - kEdge
        guard hi > lo else { set(.idle); return }
        let hour = Calendar.current.component(.hour, from: Date())
        let lateNight = hour >= 23 || hour < 5

        let options: [(Double, () -> Void)] = [
            (34, { self.targetX = .random(in: lo...hi); self.set(.walk, duration: 20) }),
            (7,  { self.targetX = .random(in: lo...hi); self.set(.run, duration: 20) }),
            (14, { self.set(.idle, duration: .random(in: 2...5)) }),
            (9,  { self.set(.stare, duration: .random(in: 2...4)) }),
            (lateNight ? 25 : 5, { self.nap(duration: lateNight ? 60 : .random(in: 12...30)) }),
            (6,  { self.dance() }),
            (6,  { self.backflip() }),
            (12, { self.trick() }),
            (5,  { self.hop() }),
            (6,  { self.chase() }),
            (8,  { if !self.tryHide() { self.set(.idle, duration: 2) } }),
            (ball == nil ? 0 : 16, { self.playBall() }),
            (trampoline == nil ? 0 : 14, { self.playTrampoline() }),
        ]
        var r = Double.random(in: 0..<options.reduce(0) { $0 + $1.0 })
        for (weight, action) in options {
            if r < weight { action(); return }
            r -= weight
        }
    }

    // MARK: Simulation

    func update(dt: Double, mouse: CGPoint) {
        let fdt = CGFloat(dt)
        time += dt
        activityTime += dt
        happyTime -= dt
        ballHitCooldown -= dt
        kickTime = max(0, kickTime - dt)
        knockCooldown -= dt

        let a = area
        let minX = a.minX + kEdge, maxX = a.maxX - kEdge, ground = a.minY

        // Blinking
        nextBlink -= dt
        if blink > 0 { blink -= dt }
        if nextBlink <= 0 { blink = 0.13; nextBlink = .random(in: 2...6) }

        // Eyes follow the cursor
        let eye = CGPoint(x: pos.x + 4 * facing, y: pos.y + 82)
        let dx = mouse.x - eye.x, dy = mouse.y - eye.y
        let len = max(1, hypot(dx, dy))
        let reach = min(1, len / 120)
        look = CGVector(dx: dx / len * reach, dy: dy / len * reach)

        // Is the user around?
        cursorDX = mouse.x - lastMouse.x
        cursorSpeed = hypot(mouse.x - lastMouse.x, mouse.y - lastMouse.y) / CGFloat(max(dt, 0.001))
        let moved = hypot(mouse.x - lastMouse.x, mouse.y - lastMouse.y) > 0.5
        lastMouse = mouse
        if moved {
            if userIdle > kAwayTime && activity == .sleep {
                set(.idle, duration: 1.5)
                say(Lines.welcomeBack.pick)
            }
            userIdle = 0
        } else {
            userIdle += dt
        }

        // Speech bubble + flapping bill
        if let s = speech {
            speechTime += dt
            let talking = speechTime < min(speechDuration - 0.4, Double(s.count) * 0.045 + 0.2)
            mouthOpen = talking ? CGFloat(abs(sin(time * 20))) : mouthOpen * 0.8
            if speechTime > speechDuration { speech = nil }
        } else {
            mouthOpen *= 0.8
        }

        // Random chatter
        if chatterEnabled && speech == nil && ![Activity.sleep, .held, .folder, .hide].contains(activity) {
            nextChatter -= dt
            if nextChatter <= 0 { say(Lines.randomChatter(agent: agent)) }
        }

        squash += (1 - squash) * min(1, fdt * 10)
        stepping = false

        // Inside a desktop folder: shrink into the icon, rummage around, pop back out
        if activity == .folder, let f = currentFolder {
            let target = CGPoint(x: f.point.x, y: f.point.y - 46)   // body centre on the icon
            if activityTime < 0.45 {
                let k = CGFloat(activityTime / 0.45)
                pos = CGPoint(x: folderFrom.x + (target.x - folderFrom.x) * k * k,
                              y: folderFrom.y + (target.y - folderFrom.y) * k * k)
                shrink = 1 - k
                spin += fdt * 14
            } else {
                pos = target
                shrink = 0
                spin = 0
                if !saidRustle && activityTime > 2.5 {
                    saidRustle = true
                    say(Lines.rustle.pick, duration: 2.2)
                }
                if activityTime > activityDuration { exitFolder() }
            }
            return
        }
        if shrink < 1 { shrink = min(1, shrink + fdt * 3.5) }

        // Being carried: dangle and flail
        if activity == .held {
            spin += (heldSwingTarget - spin) * min(1, fdt * 8)
            heldSwingTarget *= max(0, 1 - fdt * 4)
            return
        }

        // In the air: ballistic physics with wall/floor bounces
        if !onGround {
            let prevY = pos.y
            vel.dy -= kGravity * fdt
            pos.x += vel.dx * fdt
            pos.y += vel.dy * fdt
            spin += spinSpeed * fdt
            if targetFolder == nil, let t = trampoline, !t.held, vel.dy < 0,
               abs(pos.x - t.pos.x) < kMatHalfWidth + 8, prevY >= t.matY, pos.y < t.matY {
                bounceOnTrampoline(t)
            }
            if let f = targetFolder {
                if pos.y <= f.point.y + 20 { enterFolder(f); return }
                vel.dx = 0
                pos.x = f.point.x
            }
            if pos.x < minX { pos.x = minX; bonk(); vel.dx = abs(vel.dx) * 0.5; spinSpeed *= -0.6 }
            if pos.x > maxX { pos.x = maxX; bonk(); vel.dx = -abs(vel.dx) * 0.5; spinSpeed *= -0.6 }
            if targetFolder == nil && pos.y > a.maxY - 110 { pos.y = a.maxY - 110; vel.dy = -abs(vel.dy) * 0.3 }
            if pos.y <= ground {
                pos.y = ground
                let impact = -vel.dy
                if wasThrown && impact > 1500 && bounces == 0 { willBeDizzy = true }
                if wasThrown && impact > 600 && bounces < 2 {
                    bounces += 1
                    vel.dy = impact * 0.38
                    vel.dx *= 0.6
                    squash = 0.6
                } else {
                    land(impact: impact)
                }
            }
            return
        }

        // On the ground: settle upright and stay on the floor (Dock may resize)
        spin = CGFloat(remainder(Double(spin), 2 * .pi)) * max(0, 1 - fdt * 12)
        pos.y = ground
        pos.x = min(max(pos.x, minX), maxX)

        // Nobody around? Doze off.
        if userIdle > kAwayTime && activity != .sleep {
            set(.sleep, duration: .infinity)
        }

        // Cursor resting near his face → boop it
        let head = CGPoint(x: pos.x + 4 * facing, y: pos.y + 80)
        if !moved && hypot(mouse.x - head.x, mouse.y - head.y) < 80 { cursorIdle += dt } else if cursorIdle > 0 { cursorIdle = 0 }
        if cursorIdle < 0 { cursorIdle += dt }   // cooldown
        if cursorIdle > 1.4 && [Activity.idle, .stare, .walk].contains(activity) {
            cursorIdle = -6
            facing = mouse.x > pos.x ? 1 : -1
            set(.boop, duration: 1.3)
            say(Lines.fight.pick, duration: 1.4)
        }

        // Cursor swiped straight through him: knocked flying, or he flips out of the way
        if cursorSpeed > 2200 && knockCooldown <= 0 &&
           abs(mouse.x - pos.x) < 24 && mouse.y > pos.y && mouse.y < pos.y + 95 &&
           [Activity.idle, .stare, .walk, .run, .chase, .dance].contains(activity) {
            knockCooldown = 2
            let dir: CGFloat = cursorDX >= 0 ? 1 : -1
            if Double.random(in: 0..<1) < 0.35 {
                facing = -dir
                backflip()
                say(Lines.dodge.pick, duration: 1.3)
            } else {
                set(.airborne)
                onGround = false
                wasThrown = true
                bounces = 0
                willBeDizzy = false
                vel = CGVector(dx: dir * 650, dy: 600)
                spinSpeed = -dir * facing * 8
                say(Lines.knocked.pick, duration: 1.4)
            }
            return
        }

        switch activity {
        case .idle:
            if activityTime > activityDuration { chooseNext() }

        case .stare:
            facing = mouse.x > pos.x ? 1 : -1
            if activityTime > activityDuration { chooseNext() }

        case .walk, .run:
            let speed: CGFloat = activity == .run ? 280 : 85
            let dir: CGFloat = targetX > pos.x ? 1 : -1
            facing = dir
            pos.x += dir * speed * fdt
            walkPhase += fdt * (activity == .run ? 18 : 10)
            stepping = true
            if abs(targetX - pos.x) < speed * fdt + 1 || pos.x <= minX || pos.x >= maxX || activityTime > activityDuration {
                set(.idle, duration: .random(in: 1...3))
            }

        case .chase:
            let dir: CGFloat = mouse.x > pos.x ? 1 : -1
            facing = dir
            if abs(mouse.x - pos.x) > 70 {
                pos.x += dir * 300 * fdt
                walkPhase += fdt * 20
                stepping = true
            } else {
                set(.stare, duration: 2.5)
                say(Lines.caught.pick, duration: 2)
            }
            if activity == .chase && activityTime > activityDuration {
                set(.idle, duration: 1.5)
                say("Too fast for me...", duration: 2)
            }

        case .sleep:
            if activityTime > activityDuration {
                set(.idle, duration: 2)
                say(Lines.wake.pick)
            }

        case .dance:
            walkPhase += fdt * 8
            let beat = Int(activityTime / 0.45)
            if beat != lastBeat {
                lastBeat = beat
                facing = -facing
                jump(320)
            }
            if activityTime > activityDuration { set(.idle, duration: 1.5) }

        case .boop, .dizzy, .land:
            if activityTime > activityDuration { set(.idle, duration: 1.5) }

        case .trick:
            if trickKind == .handstand {                 // walk on his hands
                pos.x = min(max(pos.x + facing * 22 * fdt, minX), maxX)
                walkPhase += fdt * 5
            }
            if activityTime > activityDuration {
                if trickKind == .handstand {
                    set(.airborne)
                    jump(420)                            // pop back onto his feet
                } else {
                    set(.idle, duration: 1.5)
                }
            }

        case .hide:
            updateHide(dt: dt)

        case .fetch:
            updateFetch(dt: dt)

        case .trampoline:
            updateTrampolineApproach(dt: dt)

        case .airborne, .held, .folder:
            set(.idle, duration: 1)
        }
    }
}

// MARK: - Rendering + mouse handling

final class PetView: NSView {
    let pet: Pet
    var menuProvider: (() -> NSMenu)?
    private(set) var mouseIsDown = false
    private var dragging = false
    private var mouseDownAt = CGPoint.zero
    private var grabOffset = CGVector.zero
    private var samples: [(p: CGPoint, t: TimeInterval)] = []

    init(pet: Pet) {
        self.pet = pet
        super.init(frame: NSRect(x: 0, y: 0, width: kWinW, height: kWinH))
    }
    required init?(coder: NSCoder) { fatalError("not used") }

    override var isOpaque: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    // MARK: Mouse

    override func mouseDown(with e: NSEvent) {
        if e.modifierFlags.contains(.control) { showMenu(e); return }
        let m = NSEvent.mouseLocation
        mouseIsDown = true
        dragging = false
        mouseDownAt = m
        grabOffset = CGVector(dx: pet.pos.x - m.x, dy: pet.pos.y - m.y)
        samples = [(m, e.timestamp)]
    }

    override func mouseDragged(with e: NSEvent) {
        guard mouseIsDown else { return }
        let m = NSEvent.mouseLocation
        if !dragging && hypot(m.x - mouseDownAt.x, m.y - mouseDownAt.y) > 4 {
            dragging = true
            pet.beginHold()
        }
        guard dragging else { return }
        pet.pos = CGPoint(x: m.x + grabOffset.dx, y: m.y + grabOffset.dy)
        samples.append((m, e.timestamp))
        samples.removeAll { e.timestamp - $0.t > 0.08 }
        if let a = samples.first, let b = samples.last, b.t - a.t > 0.001 {
            let vx = (b.p.x - a.p.x) / CGFloat(b.t - a.t)
            pet.heldSwingTarget = max(-0.6, min(0.6, -vx / 2500 * pet.facing))
        }
    }

    override func mouseUp(with e: NSEvent) {
        guard mouseIsDown else { return }
        mouseIsDown = false
        if dragging {
            dragging = false
            var v = CGVector.zero
            if let a = samples.first, let b = samples.last, b.t - a.t > 0.005, e.timestamp - b.t < 0.1 {
                let dt = CGFloat(b.t - a.t)
                v = CGVector(dx: (b.p.x - a.p.x) / dt, dy: (b.p.y - a.p.y) / dt)
            }
            pet.release(velocity: v)
        } else if e.clickCount >= 2 {
            pet.backflip()
        } else {
            pet.poke()
        }
    }

    override func rightMouseDown(with e: NSEvent) { showMenu(e) }

    private func showMenu(_ e: NSEvent) {
        guard let menu = menuProvider?() else { return }
        NSMenu.popUpContextMenu(menu, with: e, for: self)
    }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.clear(bounds)
        let p = pet
        let cx = bounds.midX

        if p.shrink > 0.01 {
            // Ground shadow (shrinks as he goes up)
            let height = max(0, p.pos.y - p.area.minY)
            let s = max(0.3, 1 - height / 400)
            ctx.setFillColor(NSColor.black.withAlphaComponent(0.16 * s * p.shrink).cgColor)
            ctx.fillEllipse(in: CGRect(x: cx - 24 * s, y: kFootY - height - 4, width: 48 * s, height: 8))

            // The stick figure himself
            ctx.saveGState()
            ctx.translateBy(x: cx, y: kFootY)
            ctx.scaleBy(x: p.facing, y: 1)
            ctx.translateBy(x: 0, y: 46)
            ctx.rotate(by: p.spin)
            ctx.scaleBy(x: p.shrink, y: p.shrink)
            ctx.translateBy(x: 0, y: -46)
            ctx.scaleBy(x: 1 + (1 - p.squash) * 0.7, y: p.squash)
            drawStickman(ctx)
            ctx.restoreGState()
        }

        drawEffects(ctx, cx: cx)
        drawBubble(ctx, cx: cx)
    }

    // MARK: Stick figure

    // Bone lengths (points)
    private let thigh: CGFloat = 22, shin: CGFloat = 22
    private let upperArm: CGFloat = 17, forearm: CGFloat = 16
    private let torsoLen: CGFloat = 30, headR: CGFloat = 10
    private var hatAnchor = CGPoint.zero
    private var hatTilt: CGFloat = 0

    /// Joint angles are absolute, measured from straight down; + swings toward the way he faces.
    struct Pose {
        var torso: CGFloat = 0.04                 // lean from vertical, + = forward
        var head: CGFloat = 0                     // extra head tilt
        var armF: (CGFloat, CGFloat) = (0.14, 0.32)   // near arm: (upper arm, forearm)
        var armB: (CGFloat, CGFloat) = (-0.14, 0.0)   // far arm
        var legF: (CGFloat, CGFloat) = (0.1, 0.1)     // near leg: (thigh, shin)
        var legB: (CGFloat, CGFloat) = (-0.1, -0.1)
        var hipY: CGFloat? = nil                  // nil: plant the lowest foot on the floor
        var hipX: CGFloat = 0
        var handstand = false
    }

    /// Local coordinates: feet at y = 0, facing +x.
    private func drawStickman(_ ctx: CGContext) {
        let p = pet
        let t = CGFloat(p.time)
        let pose = currentPose()
        func off(_ o: CGPoint, _ a: CGFloat, _ l: CGFloat) -> CGPoint {
            CGPoint(x: o.x + sin(a) * l, y: o.y - cos(a) * l)
        }
        func legs(_ hip: CGPoint) -> (CGPoint, CGPoint, CGPoint, CGPoint) {
            let kF = off(hip, pose.legF.0, thigh), kB = off(hip, pose.legB.0, thigh)
            return (kF, off(kF, pose.legF.1, shin), kB, off(kB, pose.legB.1, shin))
        }
        var hip = CGPoint(x: pose.hipX, y: 0)
        let (_, f0, _, b0) = legs(hip)
        hip.y = pose.hipY ?? -min(f0.y, b0.y)
        let (kF, fF, kB, fB) = legs(hip)

        let neck = CGPoint(x: hip.x + sin(pose.torso) * torsoLen, y: hip.y + cos(pose.torso) * torsoLen)
        let shoulder = CGPoint(x: neck.x - sin(pose.torso) * 3, y: neck.y - cos(pose.torso) * 3)
        let ha = pose.torso + pose.head
        let talk = p.mouthOpen * 1.2                      // little head bob while he talks
        let headC = CGPoint(x: neck.x + sin(ha) * (headR + 3), y: neck.y + cos(ha) * (headR + 3) + talk)
        let eF = off(shoulder, pose.armF.0, upperArm), hF = off(eF, pose.armF.1, forearm)
        let eB = off(shoulder, pose.armB.0, upperArm), hB = off(eB, pose.armB.1, forearm)

        if pose.handstand {
            ctx.translateBy(x: 0, y: 52); ctx.rotate(by: .pi); ctx.translateBy(x: 0, y: -52)
        }

        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        func limb(_ pts: [CGPoint], _ w: CGFloat, _ c: NSColor) {
            ctx.move(to: pts[0])
            for q in pts.dropFirst() { ctx.addLine(to: q) }
            ctx.setStrokeColor(c.cgColor); ctx.setLineWidth(w); ctx.strokePath()
        }

        // Far limbs (a shade lighter, for depth)
        limb([hip, kB, fB], 5, Palette.inkBack)
        limb([shoulder, eB, hB], 4.5, Palette.inkBack)

        // Scarf tails stream out behind him; longer and wavier when he's moving
        let flow: CGFloat = (p.stepping || !p.onGround) ? 1 : 0.3
        ctx.move(to: CGPoint(x: neck.x - 1, y: neck.y - 2))
        for i in 1...5 {
            let k = CGFloat(i)
            ctx.addLine(to: CGPoint(x: neck.x - 1 - k * (3 + 4 * flow),
                                    y: neck.y - 2 - k * 3.2 * (1.1 - flow) + sin(t * 10 - k * 0.9) * 2.4 * flow))
        }
        ctx.setStrokeColor(Palette.scarf.cgColor); ctx.setLineWidth(4); ctx.strokePath()

        // Body and head
        limb([hip, neck], 5.5, Palette.ink)
        ctx.setFillColor(Palette.ink.cgColor)
        ctx.fillEllipse(in: CGRect(x: headC.x - headR, y: headC.y - headR, width: headR * 2, height: headR * 2))

        // Scarf wrap around the neck
        limb([CGPoint(x: neck.x - 4, y: neck.y - 1), CGPoint(x: neck.x + 4, y: neck.y + 0.5)], 5.5, Palette.scarf)

        // Near limbs
        limb([hip, kF, fF], 5, Palette.ink)
        limb([shoulder, eF, hF], 4.5, Palette.ink)

        if p.agent { drawAgentGear(ctx, head: headC, angle: ha) }

        hatAnchor = CGPoint(x: headC.x + sin(ha) * (headR - 1.5), y: headC.y + cos(ha) * (headR - 1.5))
        hatTilt = -ha
        drawHat(ctx, bob: 0, t: t)
    }

    private func currentPose() -> Pose {
        let p = pet
        let t = CGFloat(p.time)
        var pose = Pose()
        let breath = sin(t * 2.2) * 0.03
        pose.armF = (0.14 + breath, 0.32 + breath)
        pose.armB = (-0.14 - breath, -breath)
        // Angle toward the cursor (for punches and kicks), clamped so he doesn't punch his own feet
        let aim = max(0.35, min(2.9, atan2(p.look.dx * p.facing, -p.look.dy)))
        let guardF: (CGFloat, CGFloat) = (1.0, 2.6), guardB: (CGFloat, CGFloat) = (0.8, 2.5)

        switch p.activity {
        case .held:
            pose.hipY = 44
            pose.armF = (2.4 + sin(t * 17) * 0.5, 2.6 + sin(t * 17 + 1) * 0.6)
            pose.armB = (-2.4 + sin(t * 15) * 0.5, -2.2 + sin(t * 15 + 2) * 0.6)
            pose.legF = (0.3 + sin(t * 19) * 0.5, sin(t * 19 + 1) * 0.6)
            pose.legB = (-0.3 + sin(t * 21) * 0.5, -0.4 + sin(t * 21 + 2) * 0.6)
            return pose
        case .sleep:                                    // sitting, head down on his knees
            pose.hipY = 7
            pose.torso = 0.45 + sin(t * 1.3) * 0.03
            pose.head = 0.6
            pose.legF = (2.2, 0.15); pose.legB = (2.1, 0.05)          // knees up, feet on the floor
            pose.armF = (1.3, 2.0); pose.armB = (1.2, 1.9)            // arms resting on his knees
            return pose
        case .dance:
            let b = sin(t * 7)
            pose.hipX = b * 3
            pose.torso = b * 0.12
            pose.armF = (2.6 + b * 0.3, 2.9)
            pose.armB = (0.4 - b * 0.6, 1.2)
            pose.legF = (0.25 + b * 0.15, 0.1); pose.legB = (-0.25 + b * 0.15, -0.2)
            if !p.onGround { pose.hipY = 44 }
            return pose
        case .boop:                                     // jab, cross, high kick at the cursor
            let k = p.activityTime
            pose.legF = (0.35, 0.2); pose.legB = (-0.35, -0.35)
            pose.torso = 0.12
            if k < 0.3 { pose.armF = (aim, aim); pose.armB = guardB; pose.torso = 0.25 }
            else if k < 0.6 { pose.armB = (aim, aim); pose.armF = guardF; pose.torso = 0.3 }
            else if k < 1.05 {
                let kick = max(1.3, min(2.4, aim + 0.2))
                pose.legF = (kick, kick); pose.legB = (-0.15, -0.15)
                pose.torso = -0.4
                pose.armF = (1.8, 2.2); pose.armB = (-1.4, -1.0)
            } else { pose.armF = guardF; pose.armB = guardB }
            return pose
        case .land:                                     // three-point superhero landing
            pose.legF = (1.35, -0.15); pose.legB = (-0.4, -1.65)
            pose.torso = 0.75; pose.head = -0.4
            pose.armF = (0.15, 0.05); pose.armB = (-1.7, -1.3)
            return pose
        case .dizzy:
            let w = sin(t * 3)
            pose.torso = w * 0.22; pose.head = -w * 0.4
            pose.armF = (0.5 + w * 0.4, 0.9); pose.armB = (-0.5 + w * 0.4, -0.2)
            pose.legF = (0.2, 0.15); pose.legB = (-0.2, -0.1)
            return pose
        case .stare:                                    // hands on hips
            pose.armF = (0.75, -1.1); pose.armB = (-0.75, 1.1)
            pose.legF = (0.18, 0.18); pose.legB = (-0.18, -0.18)
            pose.head = 0.1
            return pose
        case .trick where p.trickKind == .handstand:
            let w = sin(p.walkPhase) * 0.15
            pose.handstand = true
            pose.hipY = 44
            pose.torso = 0
            pose.armF = (.pi - 0.12 + w, .pi - 0.12 + w)
            pose.armB = (.pi + 0.12 - w, .pi + 0.12 - w)
            pose.legF = (0.2, 0.2); pose.legB = (-0.1, -0.9)
            return pose
        case .trick where p.trickKind == .shadowbox:    // a flurry at nobody in particular
            let fwd = CGFloat.pi / 2
            pose.legF = (0.35, 0.2); pose.legB = (-0.35, -0.35)
            pose.torso = 0.15
            pose.armF = guardF; pose.armB = guardB
            switch Int(p.activityTime / 0.22) % 7 {
            case 0: pose.armF = (fwd, fwd); pose.torso = 0.3
            case 1: pose.armB = (fwd, fwd); pose.torso = 0.32
            case 2: pose.armF = (2.4, 2.9); pose.torso = 0.05           // uppercut
            case 3, 4:
                pose.legF = (2.1, 2.1); pose.legB = (-0.15, -0.15)      // high kick
                pose.torso = -0.4; pose.armF = (1.8, 2.2); pose.armB = (-1.4, -1.0)
            case 5: pose.legF = (1.1, 1.4); pose.legB = (-0.6, -1.6); pose.torso = 0.55   // low sweep
            default: break
            }
            return pose
        default:
            break
        }

        if !p.onGround && p.activity != .hide {         // in the air
            pose.hipY = 44
            if abs(p.spinSpeed) > 0.1 || p.activity == .folder {
                if p.trickKind == .cartwheel {           // star shape
                    pose.armF = (2.5, 2.5); pose.armB = (-2.5, -2.5)
                    pose.legF = (0.55, 0.55); pose.legB = (-0.55, -0.55)
                } else {                                 // tuck
                    pose.torso = 0.25
                    pose.legF = (2.0, 0.4); pose.legB = (1.8, 0.3)
                    pose.armF = (1.3, 2.3); pose.armB = (1.1, 2.1)
                }
            } else if p.vel.dy > 0 {                     // rising: arms up
                pose.armF = (2.7, 2.9); pose.armB = (2.5, 2.8)
                pose.legF = (0.15, -0.1); pose.legB = (-0.05, -0.4)
            } else {                                     // falling: flail
                pose.armF = (2.0 + sin(t * 12) * 0.3, 2.4); pose.armB = (-2.0 + sin(t * 12 + 1) * 0.3, -2.4)
                pose.legF = (0.45, 0.05); pose.legB = (-0.3, -0.7)
            }
            return pose
        }

        if p.kickTime > 0 {                              // kicking the ball
            let k = 1 - CGFloat(p.kickTime / 0.35)
            let th = -0.5 + k * 2.2
            pose.legF = (th, th - (1 - k) * 0.9); pose.legB = (-0.1, -0.1)
            pose.torso = -0.15
            pose.armF = (-0.8, -0.4); pose.armB = (1.2, 1.6)
            return pose
        }

        if p.activity == .hide {                         // sneaking: crouched, hands up, on tiptoe
            let ph = p.stepping ? p.walkPhase : 0
            pose.torso = 0.35
            pose.legF = (0.6 + 0.3 * sin(ph), -0.5 + 0.3 * sin(ph))
            pose.legB = (0.6 + 0.3 * sin(ph + .pi), -0.5 + 0.3 * sin(ph + .pi))
            pose.armF = (0.4, 2.5); pose.armB = (0.2, 2.3)
            return pose
        }

        if p.stepping {
            let ph = p.walkPhase
            let fast = [Activity.run, .chase, .fetch, .trampoline].contains(p.activity)
            let amp: CGFloat = fast ? 0.85 : 0.45, bend: CGFloat = fast ? 1.4 : 0.7
            func leg(_ ph: CGFloat) -> (CGFloat, CGFloat) {
                let th = amp * sin(ph)
                return (th, th - bend * max(0, cos(ph)) - (fast ? 0.2 : 0.05))
            }
            pose.legF = leg(ph); pose.legB = leg(ph + .pi)
            let arm = (fast ? 0.9 : 0.4) * sin(ph)
            let elbow: CGFloat = fast ? 1.5 : 0.4
            pose.armF = (-arm, -arm + elbow); pose.armB = (arm, arm + elbow)
            pose.torso = fast ? 0.3 : 0.06
            return pose
        }

        if p.happyTime > 0 {                             // poked: little cheer
            pose.armF = (2.7, 2.9); pose.armB = (2.5, 2.8)
        }
        pose.head = p.look.dy * 0.3                      // glance up/down at the cursor
        return pose
    }

    /// Secret agent: shades with a glint and a curly earpiece wire.
    private func drawAgentGear(_ ctx: CGContext, head: CGPoint, angle: CGFloat) {
        ctx.saveGState()
        ctx.translateBy(x: head.x, y: head.y)
        ctx.rotate(by: -angle)
        let lens = CGPath(roundedRect: CGRect(x: 1, y: -1, width: 10, height: 5), cornerWidth: 2, cornerHeight: 2, transform: nil)
        ctx.addPath(lens); ctx.setFillColor(NSColor(white: 0.3, alpha: 1).cgColor); ctx.fillPath()
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.85).cgColor); ctx.setLineWidth(1.2)
        ctx.move(to: CGPoint(x: 3.5, y: 3)); ctx.addLine(to: CGPoint(x: 6, y: 0)); ctx.strokePath()
        ctx.setStrokeColor(NSColor(white: 0.62, alpha: 1).cgColor); ctx.setLineWidth(1.1)
        ctx.move(to: CGPoint(x: -4, y: -2))
        for i in 0..<5 {
            let y = -2 - CGFloat(i + 1) * 3
            ctx.addQuadCurve(to: CGPoint(x: -4, y: y), control: CGPoint(x: i % 2 == 0 ? -8 : 0, y: y + 1.5))
        }
        ctx.strokePath()
        ctx.restoreGState()
    }

    /// Hats sit on top of his head; drawStickman sets hatAnchor/hatTilt each frame.
    private func drawHat(_ ctx: CGContext, bob: CGFloat, t: CGFloat) {
        let hat = pet.hat
        guard hat != .none else { return }
        ctx.saveGState()
        ctx.translateBy(x: hatAnchor.x, y: hatAnchor.y + bob)
        ctx.rotate(by: hatTilt)
        ctx.scaleBy(x: 0.8, y: 0.8)
        let ink = Palette.outline.cgColor
        func outlined(_ path: CGPath, _ fill: NSColor, width: CGFloat = 2) {
            ctx.addPath(path); ctx.setFillColor(fill.cgColor); ctx.fillPath()
            ctx.addPath(path); ctx.setStrokeColor(ink); ctx.setLineWidth(width); ctx.strokePath()
        }
        switch hat {
        case .none:
            break
        case .party:
            let cone = CGMutablePath()
            cone.move(to: CGPoint(x: -11, y: 0)); cone.addLine(to: CGPoint(x: 11, y: 0)); cone.addLine(to: CGPoint(x: 1, y: 28))
            cone.closeSubpath()
            outlined(cone, NSColor(srgbRed: 1, green: 0.42, blue: 0.62, alpha: 1))
            ctx.saveGState()
            ctx.addPath(cone); ctx.clip()
            ctx.setStrokeColor(NSColor(srgbRed: 1, green: 0.85, blue: 0.3, alpha: 1).cgColor); ctx.setLineWidth(3)
            for y in stride(from: CGFloat(4), to: 28, by: 8) {
                ctx.move(to: CGPoint(x: -14, y: y - 4)); ctx.addLine(to: CGPoint(x: 14, y: y + 4))
            }
            ctx.strokePath()
            ctx.restoreGState()
            outlined(CGPath(ellipseIn: CGRect(x: -3, y: 25, width: 8, height: 8), transform: nil), NSColor(srgbRed: 1, green: 0.85, blue: 0.3, alpha: 1), width: 1.5)
        case .top:
            outlined(CGPath(roundedRect: CGRect(x: -18, y: -1, width: 36, height: 6), cornerWidth: 3, cornerHeight: 3, transform: nil), NSColor(white: 0.12, alpha: 1))
            outlined(CGPath(roundedRect: CGRect(x: -11, y: 3, width: 22, height: 24), cornerWidth: 2, cornerHeight: 2, transform: nil), NSColor(white: 0.12, alpha: 1))
            ctx.setFillColor(NSColor(srgbRed: 0.85, green: 0.2, blue: 0.3, alpha: 1).cgColor)
            ctx.fill(CGRect(x: -10, y: 6, width: 20, height: 4))
        case .crown:
            let crown = CGMutablePath()
            crown.move(to: CGPoint(x: -13, y: 0)); crown.addLine(to: CGPoint(x: 13, y: 0))
            crown.addLine(to: CGPoint(x: 14, y: 16)); crown.addLine(to: CGPoint(x: 7, y: 8))
            crown.addLine(to: CGPoint(x: 0, y: 19)); crown.addLine(to: CGPoint(x: -7, y: 8))
            crown.addLine(to: CGPoint(x: -14, y: 16)); crown.closeSubpath()
            outlined(crown, Palette.star)
            for x in [-7, 0, 7] as [CGFloat] {
                ctx.setFillColor(NSColor(srgbRed: 0.9, green: 0.2, blue: 0.35, alpha: 1).cgColor)
                ctx.fillEllipse(in: CGRect(x: x - 2, y: 2.5, width: 4, height: 4))
            }
        case .propeller:
            let dome = CGMutablePath()
            dome.addArc(center: .zero, radius: 13, startAngle: 0, endAngle: .pi, clockwise: false)
            dome.closeSubpath()
            outlined(dome, NSColor(srgbRed: 0.98, green: 0.78, blue: 0.2, alpha: 1))
            ctx.saveGState()
            ctx.addPath(dome); ctx.clip()
            ctx.setFillColor(NSColor(srgbRed: 0.9, green: 0.25, blue: 0.3, alpha: 1).cgColor)
            ctx.fill(CGRect(x: -4.5, y: 0, width: 9, height: 14))
            ctx.restoreGState()
            ctx.setStrokeColor(ink); ctx.setLineWidth(2)
            ctx.move(to: CGPoint(x: 0, y: 13)); ctx.addLine(to: CGPoint(x: 0, y: 18)); ctx.strokePath()
            let spinRate: CGFloat = pet.onGround ? 8 : 30
            let w = abs(cos(t * spinRate)) * 13 + 2
            outlined(CGPath(ellipseIn: CGRect(x: -w, y: 16.5, width: w * 2, height: 4), transform: nil), NSColor(srgbRed: 0.25, green: 0.55, blue: 0.95, alpha: 1), width: 1.5)
        case .beanie:
            let dome = CGMutablePath()
            dome.addArc(center: CGPoint(x: 0, y: 2), radius: 13, startAngle: 0, endAngle: .pi, clockwise: false)
            dome.closeSubpath()
            outlined(dome, NSColor(srgbRed: 0.95, green: 0.45, blue: 0.2, alpha: 1))
            outlined(CGPath(roundedRect: CGRect(x: -14, y: -1, width: 28, height: 6), cornerWidth: 3, cornerHeight: 3, transform: nil), NSColor(srgbRed: 0.8, green: 0.3, blue: 0.15, alpha: 1))
            outlined(CGPath(ellipseIn: CGRect(x: -4, y: 13, width: 8, height: 8), transform: nil), NSColor.white, width: 1.5)
        }
        ctx.restoreGState()
    }

    /// Zs when sleeping, notes when dancing, stars when dizzy.
    private func drawEffects(_ ctx: CGContext, cx: CGFloat) {
        let p = pet
        let t = CGFloat(p.time)
        func glyph(_ s: String, at pt: CGPoint, size: CGFloat, color: NSColor) {
            NSAttributedString(string: s, attributes: [
                .font: NSFont.systemFont(ofSize: size, weight: .heavy),
                .foregroundColor: color,
            ]).draw(at: pt)
        }
        switch p.activity {
        case .sleep:
            for i in 0..<3 {
                let ph = (t * 0.45 + CGFloat(i) / 3).truncatingRemainder(dividingBy: 1)
                let x = cx + p.facing * (12 + ph * 26) - 6
                glyph(i % 2 == 0 ? "z" : "Z",
                      at: CGPoint(x: x, y: kFootY + 58 + ph * 50),
                      size: 10 + ph * 9,
                      color: Palette.outline.withAlphaComponent(sin(ph * .pi) * 0.8))
            }
        case .dance:
            for i in 0..<2 {
                let ph = (t * 0.7 + CGFloat(i) / 2).truncatingRemainder(dividingBy: 1)
                let side: CGFloat = i == 0 ? -1 : 1
                glyph(i == 0 ? "♪" : "♫",
                      at: CGPoint(x: cx + side * (32 + sin(ph * 6) * 6) - 7, y: kFootY + 80 + ph * 55),
                      size: 18,
                      color: Palette.tail.withAlphaComponent(sin(ph * .pi)))
            }
        case .dizzy:
            let c = CGPoint(x: cx + p.facing * 4, y: kFootY + 100)
            for i in 0..<3 {
                let a = t * 5 + CGFloat(i) * 2 * .pi / 3
                glyph("★", at: CGPoint(x: c.x + cos(a) * 24 - 6, y: c.y + sin(a) * 6 - 7), size: 13, color: Palette.star)
            }
        default:
            break
        }
    }

    private func drawBubble(_ ctx: CGContext, cx: CGFloat) {
        guard let text = pet.speech else { return }
        let base = NSFont.systemFont(ofSize: 13, weight: .semibold)
        let font = base.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: 13) } ?? base
        let para = NSMutableParagraphStyle()
        para.alignment = .center
        let str = NSAttributedString(string: text, attributes: [
            .font: font, .foregroundColor: Palette.outline, .paragraphStyle: para,
        ])
        let opts: NSString.DrawingOptions = [.usesLineFragmentOrigin, .usesFontLeading]
        let tb = str.boundingRect(with: CGSize(width: 200, height: 1000), options: opts)
        let padX: CGFloat = 12, padY: CGFloat = 8
        let w = ceil(tb.width) + padX * 2, h = ceil(tb.height) + padY * 2

        let anchor = CGPoint(x: cx + pet.facing * 6, y: kFootY + 100)
        var x = anchor.x - w / 2
        x = min(max(x, 4), bounds.width - w - 4)
        // Keep the bubble on-screen near the edges
        if let win = window, let scr = win.screen ?? NSScreen.main {
            let vf = scr.visibleFrame
            let lo = vf.minX - win.frame.minX + 4, hi = vf.maxX - win.frame.minX - w - 4
            if lo <= hi { x = min(max(x, lo), hi) }
        }
        let rect = CGRect(x: x, y: anchor.y + 14, width: w, height: h)

        // Pop in with a little overshoot, fade out at the end
        let k = CGFloat(min(1, pet.speechTime / 0.18))
        let c1: CGFloat = 1.70158, c3 = c1 + 1
        let scale = 1 + c3 * pow(k - 1, 3) + c1 * pow(k - 1, 2)
        let alpha = CGFloat(max(0, min(1, (pet.speechDuration - pet.speechTime) / 0.3)))

        ctx.saveGState()
        ctx.setAlpha(alpha)
        ctx.translateBy(x: anchor.x, y: anchor.y)
        ctx.scaleBy(x: scale, y: scale)
        ctx.translateBy(x: -anchor.x, y: -anchor.y)

        let tx = min(max(anchor.x, rect.minX + 18), rect.maxX - 18)
        let shape = CGMutablePath()
        shape.addRoundedRect(in: rect, cornerWidth: 12, cornerHeight: 12)
        shape.move(to: CGPoint(x: tx - 8, y: rect.minY + 2))
        shape.addLine(to: CGPoint(x: anchor.x, y: anchor.y + 2))
        shape.addLine(to: CGPoint(x: tx + 8, y: rect.minY + 2))
        shape.closeSubpath()

        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -2), blur: 6, color: NSColor.black.withAlphaComponent(0.25).cgColor)
        ctx.addPath(shape); ctx.setStrokeColor(Palette.outline.cgColor); ctx.setLineWidth(4); ctx.setLineJoin(.round); ctx.strokePath()
        ctx.restoreGState()
        ctx.addPath(shape); ctx.setFillColor(NSColor.white.cgColor); ctx.fillPath()

        str.draw(with: CGRect(x: rect.minX + padX, y: rect.minY + padY, width: w - padX * 2, height: ceil(tb.height)), options: opts)
        ctx.restoreGState()
    }
}

// MARK: - Folder debug overlay

/// Full-screen, click-through layer that shows where Stix thinks the desktop folders are.
final class FolderDebugView: NSView {
    let pet: Pet
    init(pet: Pet, frame: NSRect) { self.pet = pet; super.init(frame: frame) }
    required init?(coder: NSCoder) { fatalError("not used") }
    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext, let win = window else { return }
        ctx.clear(bounds)
        let o = win.frame.origin
        func local(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x - o.x, y: p.y - o.y) }
        let label: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .bold),
            .foregroundColor: NSColor.white,
            .backgroundColor: NSColor.black.withAlphaComponent(0.7),
        ]
        let feet = local(pet.pos)
        for f in pet.knownFolders {
            let zone = Pet.dropZone(for: f).offsetBy(dx: -o.x, dy: -o.y)
            let hot = Pet.dropZone(for: f).contains(pet.pos)
            ctx.setFillColor((hot ? NSColor.systemGreen : NSColor.systemRed).withAlphaComponent(0.12).cgColor)
            ctx.fill(zone)
            ctx.setStrokeColor((hot ? NSColor.systemGreen : NSColor.systemRed).cgColor)
            ctx.setLineWidth(2)
            ctx.setLineDash(phase: 0, lengths: [6, 4])
            ctx.stroke(zone)
            ctx.setLineDash(phase: 0, lengths: [])
            // Crosshair where Finder says the icon is
            let c = local(f.point)
            ctx.setLineWidth(2.5)
            ctx.move(to: CGPoint(x: c.x - 14, y: c.y)); ctx.addLine(to: CGPoint(x: c.x + 14, y: c.y))
            ctx.move(to: CGPoint(x: c.x, y: c.y - 14)); ctx.addLine(to: CGPoint(x: c.x, y: c.y + 14))
            ctx.strokePath()
            NSAttributedString(string: " \(f.name)  (\(Int(f.point.x)), \(Int(f.point.y))) ", attributes: label)
                .draw(at: CGPoint(x: c.x + 16, y: c.y + 4))
        }
        // His feet: this is the point that has to be inside a box when you let go
        ctx.setFillColor(NSColor.systemYellow.cgColor)
        ctx.fillEllipse(in: CGRect(x: feet.x - 6, y: feet.y - 6, width: 12, height: 12))
        ctx.setStrokeColor(NSColor.black.cgColor); ctx.setLineWidth(1.5)
        ctx.strokeEllipse(in: CGRect(x: feet.x - 6, y: feet.y - 6, width: 12, height: 12))
        let mouse = NSEvent.mouseLocation
        var info = "feet (\(Int(pet.pos.x)), \(Int(pet.pos.y)))   cursor (\(Int(mouse.x)), \(Int(mouse.y)))   "
        info += "folders: \(pet.knownFolders.count)   last drop speed: \(Int(pet.lastDropSpeed)) (max \(Int(kMaxDropSpeed)))"
        if let e = FinderBridge.lastError { info += "\nFinder error: \(e)" }
        if pet.knownFolders.isEmpty, let raw = FinderBridge.lastFolderReply {
            let shown = raw.prefix(300).replacingOccurrences(of: "\t", with: " ⇥ ").replacingOccurrences(of: "\r", with: "␍")
            info += "\nFinder's raw reply (\(raw.count) chars): " + (shown.isEmpty ? "(empty)" : shown)
        }
        NSAttributedString(string: info, attributes: label).draw(at: CGPoint(x: feet.x + 10, y: feet.y - 30))
    }
}

// MARK: - Toys (soccer ball, trampoline)

let kMatHeight: CGFloat = 28       // trampoline mat height above the floor
let kMatHalfWidth: CGFloat = 52
let kBallRadius: CGFloat = 17

@MainActor
func usableArea(at p: CGPoint) -> CGRect {
    let probe = CGPoint(x: p.x, y: p.y + 20)
    return (NSScreen.screens.first { $0.frame.contains(probe) } ?? NSScreen.main ?? NSScreen.screens[0]).visibleFrame
}

@MainActor
final class Prop {
    enum Kind { case ball, trampoline }
    let kind: Kind
    /// Ball: its centre. Trampoline: the middle of its feet on the floor.
    var pos: CGPoint
    var vel = CGVector.zero
    var spin: CGFloat = 0
    var dip: CGFloat = 0           // trampoline mat sag, 0...1
    var held = false
    var onGround = false
    var panel: PetPanel!
    var view: PropView!

    init(kind: Kind, at p: CGPoint) {
        self.kind = kind
        self.pos = p
    }

    var winSize: CGSize { kind == .ball ? CGSize(width: 70, height: 70) : CGSize(width: 170, height: 90) }
    /// Where `pos` sits inside the window.
    var anchor: CGPoint { kind == .ball ? CGPoint(x: 35, y: 35) : CGPoint(x: 85, y: 12) }
    var matY: CGFloat { pos.y + kMatHeight }

    func hitTest(screenPoint m: CGPoint) -> Bool {
        switch kind {
        case .ball: return hypot(m.x - pos.x, m.y - pos.y) < kBallRadius + 8
        case .trampoline: return CGRect(x: pos.x - 66, y: pos.y - 2, width: 132, height: kMatHeight + 14).contains(m)
        }
    }

    func update(dt: Double, pet: Pet, trampoline: Prop?) {
        let fdt = CGFloat(dt)
        dip -= dip * min(1, fdt * 9)
        guard !held else { return }
        let a = usableArea(at: pos)
        let floorY = kind == .ball ? a.minY + kBallRadius : a.minY
        let r: CGFloat = kind == .ball ? kBallRadius : 66

        let prevY = pos.y
        vel.dy -= kGravity * fdt
        pos.x += vel.dx * fdt
        pos.y += vel.dy * fdt

        if pos.x < a.minX + r { pos.x = a.minX + r; vel.dx = abs(vel.dx) * 0.7 }
        if pos.x > a.maxX - r { pos.x = a.maxX - r; vel.dx = -abs(vel.dx) * 0.7 }
        if pos.y > a.maxY - r { pos.y = a.maxY - r; vel.dy = -abs(vel.dy) * 0.5 }

        if kind == .ball {
            // Bounce on the trampoline
            if let t = trampoline, !t.held, vel.dy < 0, abs(pos.x - t.pos.x) < kMatHalfWidth,
               prevY - kBallRadius >= t.matY, pos.y - kBallRadius < t.matY {
                pos.y = t.matY + kBallRadius
                vel.dy = max(700, -vel.dy * 0.9)
                t.dip = min(1, t.dip + 0.5)
            }
            collide(with: pet)
            spin -= vel.dx * fdt / kBallRadius        // roll
        }

        onGround = false
        if pos.y <= floorY {
            pos.y = floorY
            if kind == .ball && vel.dy < -120 {
                vel.dy = -vel.dy * 0.62
            } else {
                vel.dy = 0
                onGround = true
            }
            vel.dx *= kind == .ball ? max(0, 1 - fdt * 1.2) : 0   // rolling friction
            if abs(vel.dx) < 4 { vel.dx = 0 }
        }
    }

    /// The ball bounces off him (treated as a box around his body).
    private func collide(with pet: Pet) {
        guard pet.shrink > 0.9, pet.hideBehind == nil else { return }
        let box = CGRect(x: pet.pos.x - 13, y: pet.pos.y + 2, width: 26, height: 90)
        let closest = CGPoint(x: min(max(pos.x, box.minX), box.maxX), y: min(max(pos.y, box.minY), box.maxY))
        var n = CGVector(dx: pos.x - closest.x, dy: pos.y - closest.y)
        var d = hypot(n.dx, n.dy)
        if d >= kBallRadius { return }
        if d < 0.001 { n = CGVector(dx: 0, dy: 1); d = 1 }   // centre inside him: pop it upward
        n = CGVector(dx: n.dx / d, dy: n.dy / d)
        let rel = CGVector(dx: vel.dx - pet.vel.dx, dy: vel.dy - pet.vel.dy)
        let along = rel.dx * n.dx + rel.dy * n.dy
        guard along < 0 else { return }                        // already moving away
        vel.dx -= 1.6 * along * n.dx
        vel.dy -= 1.6 * along * n.dy
        pos.x = closest.x + n.dx * kBallRadius
        pos.y = closest.y + n.dy * kBallRadius
        pet.gotHitByBall(speed: -along, fromAbove: n.dy > 0.7)
    }
}

final class PropView: NSView {
    let prop: Prop
    var onRemove: (() -> Void)?
    private(set) var mouseIsDown = false
    private var dragging = false
    private var downAt = CGPoint.zero
    private var grab = CGVector.zero
    private var samples: [(p: CGPoint, t: TimeInterval)] = []

    init(prop: Prop) {
        self.prop = prop
        super.init(frame: NSRect(origin: .zero, size: prop.winSize))
    }
    required init?(coder: NSCoder) { fatalError("not used") }
    override var isOpaque: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with e: NSEvent) {
        if e.modifierFlags.contains(.control) { showMenu(e); return }
        let m = NSEvent.mouseLocation
        mouseIsDown = true
        dragging = false
        downAt = m
        grab = CGVector(dx: prop.pos.x - m.x, dy: prop.pos.y - m.y)
        samples = [(m, e.timestamp)]
    }

    override func mouseDragged(with e: NSEvent) {
        guard mouseIsDown else { return }
        let m = NSEvent.mouseLocation
        if !dragging && hypot(m.x - downAt.x, m.y - downAt.y) > 4 {
            dragging = true
            prop.held = true
        }
        guard dragging else { return }
        prop.pos = CGPoint(x: m.x + grab.dx, y: m.y + grab.dy)
        samples.append((m, e.timestamp))
        samples.removeAll { e.timestamp - $0.t > 0.08 }
    }

    override func mouseUp(with e: NSEvent) {
        guard mouseIsDown else { return }
        mouseIsDown = false
        if dragging {
            dragging = false
            prop.held = false
            prop.vel = .zero
            if prop.kind == .ball, let a = samples.first, let b = samples.last, b.t - a.t > 0.005, e.timestamp - b.t < 0.1 {
                let dt = CGFloat(b.t - a.t)
                prop.vel = CGVector(dx: (b.p.x - a.p.x) / dt, dy: (b.p.y - a.p.y) / dt)
            }
        } else if prop.kind == .ball {
            prop.vel = CGVector(dx: .random(in: -200...200), dy: 700)   // flick it up
        } else {
            prop.dip = 1
        }
    }

    override func rightMouseDown(with e: NSEvent) { showMenu(e) }

    private func showMenu(_ e: NSEvent) {
        let menu = NSMenu()
        let item = NSMenuItem(title: prop.kind == .ball ? "Put Away Ball" : "Put Away Trampoline",
                              action: #selector(remove), keyEquivalent: "")
        item.target = self
        menu.addItem(item)
        NSMenu.popUpContextMenu(menu, with: e, for: self)
    }

    @objc private func remove() { onRemove?() }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.clear(bounds)
        let a = prop.anchor
        ctx.translateBy(x: a.x, y: a.y)
        switch prop.kind {
        case .ball: drawBall(ctx)
        case .trampoline: drawTrampoline(ctx)
        }
    }

    private func drawBall(_ ctx: CGContext) {
        let r = kBallRadius
        // Shadow when it's close to the floor
        let height = prop.pos.y - kBallRadius - usableArea(at: prop.pos).minY
        if height < 30 {
            let k = 1 - max(0, height) / 30
            ctx.setFillColor(NSColor.black.withAlphaComponent(0.18 * k).cgColor)
            ctx.fillEllipse(in: CGRect(x: -r, y: -r - height - 3, width: r * 2, height: 6))
        }
        let disc = CGRect(x: -r, y: -r, width: r * 2, height: r * 2)
        ctx.setFillColor(Palette.outline.cgColor)
        ctx.fillEllipse(in: disc.insetBy(dx: -2, dy: -2))
        ctx.setFillColor(NSColor.white.cgColor)
        ctx.fillEllipse(in: disc)

        ctx.saveGState()
        ctx.addEllipse(in: disc); ctx.clip()
        ctx.rotate(by: prop.spin)
        func pentagon(center c: CGPoint, radius pr: CGFloat, rotation: CGFloat) {
            for i in 0..<5 {
                let ang = rotation + CGFloat(i) * 2 * .pi / 5 + .pi / 2
                let pt = CGPoint(x: c.x + cos(ang) * pr, y: c.y + sin(ang) * pr)
                if i == 0 { ctx.move(to: pt) } else { ctx.addLine(to: pt) }
            }
            ctx.closePath()
        }
        ctx.setFillColor(NSColor(white: 0.12, alpha: 1).cgColor)
        pentagon(center: .zero, radius: 6.5, rotation: 0)
        ctx.fillPath()
        ctx.setStrokeColor(NSColor(white: 0.12, alpha: 1).cgColor)
        ctx.setLineWidth(1.4)
        for i in 0..<5 {
            let ang = CGFloat(i) * 2 * .pi / 5 + .pi / 2
            ctx.move(to: CGPoint(x: cos(ang) * 6.5, y: sin(ang) * 6.5))
            ctx.addLine(to: CGPoint(x: cos(ang) * 13, y: sin(ang) * 13))
        }
        ctx.strokePath()
        for i in 0..<5 {
            let ang = CGFloat(i) * 2 * .pi / 5 + .pi / 2
            pentagon(center: CGPoint(x: cos(ang) * 18, y: sin(ang) * 18), radius: 5.5, rotation: .pi)
        }
        ctx.fillPath()
        ctx.restoreGState()
        // Shine
        ctx.setFillColor(NSColor.white.withAlphaComponent(0.55).cgColor)
        ctx.fillEllipse(in: CGRect(x: -r * 0.55, y: r * 0.25, width: 7, height: 5))
    }

    private func drawTrampoline(_ ctx: CGContext) {
        let blue = NSColor(srgbRed: 0.18, green: 0.42, blue: 0.90, alpha: 1)
        let legs = NSColor(white: 0.45, alpha: 1)
        // Floor shadow
        ctx.setFillColor(NSColor.black.withAlphaComponent(0.15).cgColor)
        ctx.fillEllipse(in: CGRect(x: -68, y: -5, width: 136, height: 9))
        // Legs
        ctx.setLineCap(.round)
        ctx.setStrokeColor(legs.cgColor); ctx.setLineWidth(4)
        for (top, bottom) in [(-50, -58), (-18, -22), (18, 22), (50, 58)] as [(CGFloat, CGFloat)] {
            ctx.move(to: CGPoint(x: top, y: kMatHeight - 3)); ctx.addLine(to: CGPoint(x: bottom, y: 0))
        }
        ctx.strokePath()
        // Mat (sags when something lands on it)
        let sag = prop.dip * 16
        ctx.setStrokeColor(NSColor(white: 0.1, alpha: 1).cgColor); ctx.setLineWidth(4)
        ctx.move(to: CGPoint(x: -kMatHalfWidth, y: kMatHeight))
        ctx.addQuadCurve(to: CGPoint(x: kMatHalfWidth, y: kMatHeight), control: CGPoint(x: 0, y: kMatHeight - sag * 2))
        ctx.strokePath()
        // Springs
        ctx.setStrokeColor(NSColor(white: 0.6, alpha: 1).cgColor); ctx.setLineWidth(1.5)
        for side in [-1, 1] as [CGFloat] {
            var x = side * kMatHalfWidth
            ctx.move(to: CGPoint(x: x, y: kMatHeight))
            for i in 0..<4 {
                x += side * 2
                ctx.addLine(to: CGPoint(x: x, y: kMatHeight + (i % 2 == 0 ? 2.5 : -2.5)))
            }
        }
        ctx.strokePath()
        // Padded rim at each end
        let rim = CGPath(roundedRect: CGRect(x: -66, y: kMatHeight - 4, width: 14, height: 8), cornerWidth: 4, cornerHeight: 4, transform: nil)
        let rim2 = CGPath(roundedRect: CGRect(x: 52, y: kMatHeight - 4, width: 14, height: 8), cornerWidth: 4, cornerHeight: 4, transform: nil)
        for path in [rim, rim2] {
            ctx.addPath(path); ctx.setFillColor(blue.cgColor); ctx.fillPath()
            ctx.addPath(path); ctx.setStrokeColor(Palette.outline.cgColor); ctx.setLineWidth(1.5); ctx.strokePath()
        }
    }
}

// MARK: - Window

final class PetPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    // Let him hang partly off-screen without AppKit shoving the window around.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}

// MARK: - App

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let pet = Pet()
    private var panel: PetPanel!
    private var view: PetView!
    private var statusItem: NSStatusItem!
    private var timer: Timer?
    private var lastTick = CACurrentMediaTime()
    private var appliedHide: Int?
    private var debugPanel: NSPanel?
    private var props: [Prop] = []
    private let defaults = UserDefaults.standard

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Drop in from the top of the screen
        let vf = (NSScreen.main ?? NSScreen.screens[0]).visibleFrame
        pet.pos = CGPoint(x: .random(in: (vf.minX + 200)...(max(vf.minX + 201, vf.maxX - 200))), y: vf.maxY - 120)
        pet.facing = Bool.random() ? 1 : -1
        pet.hat = Hat(rawValue: defaults.string(forKey: "hat") ?? "") ?? .none
        pet.agent = defaults.bool(forKey: "agent")

        panel = PetPanel(contentRect: NSRect(x: 0, y: 0, width: kWinW, height: kWinH),
                         styleMask: [.borderless, .nonactivatingPanel],
                         backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]

        view = PetView(pet: pet)
        view.menuProvider = { [weak self] in self?.buildMenu() ?? NSMenu() }
        panel.contentView = view
        positionWindow()
        panel.orderFrontRegardless()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            if let img = NSImage(systemSymbolName: "figure.walk", accessibilityDescription: "Stix") {
                img.isTemplate = true
                button.image = img
            } else {
                button.title = "웃"
            }
        }
        statusItem.menu = buildMenu()
        pet.refreshFolders()   // first run: macOS asks permission for Stix to control Finder

        let t = Timer(timeInterval: 1.0 / 60.0, target: self, selector: #selector(tick), userInfo: nil, repeats: true)
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    @objc private func tick() {
        let now = CACurrentMediaTime()
        let dt = min(1.0 / 20.0, now - lastTick)
        lastTick = now

        let mouse = NSEvent.mouseLocation
        pet.update(dt: dt, mouse: mouse)
        positionWindow()

        // Hiding: drop to the normal window layer, tucked just below the chosen window.
        if pet.hideBehind != appliedHide {
            appliedHide = pet.hideBehind
            if let number = appliedHide {
                panel.level = .normal
                panel.order(.below, relativeTo: number)
            } else {
                panel.level = .floating
                panel.orderFrontRegardless()
            }
        }

        // The window is click-through everywhere except right over him.
        let f = panel.frame
        let local = CGPoint(x: mouse.x - f.minX, y: mouse.y - f.minY)
        let hitBox = CGRect(x: f.width / 2 - 32, y: kFootY - 6, width: 64, height: 110)
        panel.ignoresMouseEvents = !((hitBox.contains(local) && pet.shrink > 0.5) || view.mouseIsDown)

        view.needsDisplay = true
        debugPanel?.contentView?.needsDisplay = true

        for prop in props {
            prop.update(dt: dt, pet: pet, trampoline: pet.trampoline)
            let a = prop.anchor
            prop.panel.setFrameOrigin(NSPoint(x: prop.pos.x - a.x, y: prop.pos.y - a.y))
            prop.panel.ignoresMouseEvents = !(prop.hitTest(screenPoint: mouse) || prop.view.mouseIsDown)
            prop.view.needsDisplay = true
        }
    }

    // MARK: Toys

    private func addToy(_ kind: Prop.Kind) {
        let a = pet.area
        let x = min(max(pet.pos.x + pet.facing * 200, a.minX + 90), a.maxX - 90)
        let prop = Prop(kind: kind, at: CGPoint(x: x, y: a.maxY - 120))   // drops in from the top
        let p = PetPanel(contentRect: NSRect(origin: .zero, size: prop.winSize),
                         styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.level = .floating
        p.hidesOnDeactivate = false
        p.isMovable = false
        p.becomesKeyOnlyIfNeeded = true
        p.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        let v = PropView(prop: prop)
        v.onRemove = { [weak self, weak prop] in
            guard let self, let prop else { return }
            self.removeToy(prop)
        }
        p.contentView = v
        prop.panel = p
        prop.view = v
        p.orderFrontRegardless()
        if pet.hideBehind == nil { panel.orderFrontRegardless() }   // he stays in front of his toys
        props.append(prop)
        switch kind {
        case .ball: pet.ball = prop
        case .trampoline: pet.trampoline = prop
        }
        pet.say(Lines.newToy.pick, duration: 1.8)
        statusItem.menu = buildMenu()
    }

    private func removeToy(_ prop: Prop) {
        prop.panel.orderOut(nil)
        props.removeAll { $0 === prop }
        if pet.ball === prop { pet.ball = nil }
        if pet.trampoline === prop { pet.trampoline = nil }
        statusItem.menu = buildMenu()
    }

    private func toggleToy(_ kind: Prop.Kind) {
        if let existing = props.first(where: { $0.kind == kind }) { removeToy(existing) } else { addToy(kind) }
    }

    private func positionWindow() {
        panel.setFrameOrigin(NSPoint(x: pet.pos.x - kWinW / 2, y: pet.pos.y - kFootY))
    }

    // MARK: Menu

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        func add(_ title: String, _ action: Selector, key: String = "") {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
            item.target = self
            menu.addItem(item)
        }
        add("Say Something", #selector(menuSay))
        add("Come Here", #selector(menuCome))
        add("Backflip!", #selector(menuFlip))
        add("Dance", #selector(menuDance))
        add("Take a Nap", #selector(menuNap))
        add("Hide!", #selector(menuHide))
        menu.addItem(.separator())

        // Toys ▸
        let toys = NSMenu()
        for (title, kind, action) in [("Soccer Ball", Prop.Kind.ball, #selector(menuToggleBall)),
                                      ("Trampoline", Prop.Kind.trampoline, #selector(menuToggleTrampoline))] {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
            item.target = self
            item.state = props.contains { $0.kind == kind } ? .on : .off
            toys.addItem(item)
        }
        toys.addItem(.separator())
        let play = NSMenuItem(title: "Play with Ball", action: #selector(menuPlayBall), keyEquivalent: "")
        play.target = self
        play.isEnabled = pet.ball != nil
        toys.addItem(play)
        let bounce = NSMenuItem(title: "Jump on Trampoline", action: #selector(menuPlayTrampoline), keyEquivalent: "")
        bounce.target = self
        bounce.isEnabled = pet.trampoline != nil
        toys.addItem(bounce)
        toys.autoenablesItems = false
        let toysItem = NSMenuItem(title: "Toys", action: nil, keyEquivalent: "")
        toysItem.submenu = toys
        menu.addItem(toysItem)

        // Hat ▸
        let hats = NSMenu()
        for hat in Hat.allCases {
            let item = NSMenuItem(title: hat.title, action: #selector(menuPickHat(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = hat.rawValue
            item.state = pet.hat == hat ? .on : .off
            hats.addItem(item)
        }
        let hatItem = NSMenuItem(title: "Hat", action: nil, keyEquivalent: "")
        hatItem.submenu = hats
        menu.addItem(hatItem)

        let agent = NSMenuItem(title: "Secret Agent Mode", action: #selector(menuToggleAgent), keyEquivalent: "")
        agent.target = self
        agent.state = pet.agent ? .on : .off
        menu.addItem(agent)
        menu.addItem(.separator())
        let chatty = NSMenuItem(title: "Chatty", action: #selector(menuToggleChatter), keyEquivalent: "")
        chatty.target = self
        chatty.state = pet.chatterEnabled ? .on : .off
        menu.addItem(chatty)
        let debug = NSMenuItem(title: "Debug Desktop Folders", action: #selector(menuToggleFolderDebug), keyEquivalent: "")
        debug.target = self
        debug.state = pet.debugFolders ? .on : .off
        menu.addItem(debug)
        menu.addItem(.separator())
        add("Quit Stix", #selector(menuQuit), key: "q")
        return menu
    }

    @objc private func menuSay()   { pet.saySomething() }
    @objc private func menuCome()  { pet.come(to: NSEvent.mouseLocation.x) }
    @objc private func menuFlip()  { pet.backflip() }
    @objc private func menuDance() { pet.dance() }
    @objc private func menuNap()   { pet.nap() }
    @objc private func menuToggleFolderDebug() {
        pet.debugFolders.toggle()
        if pet.debugFolders {
            let frame = NSScreen.screens.reduce(NSRect.null) { $0.union($1.frame) }
            let p = PetPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            p.isOpaque = false
            p.backgroundColor = .clear
            p.hasShadow = false
            p.ignoresMouseEvents = true
            p.hidesOnDeactivate = false
            p.level = .floating
            p.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            p.contentView = FolderDebugView(pet: pet, frame: NSRect(origin: .zero, size: frame.size))
            p.setFrame(frame, display: false)
            p.orderFrontRegardless()
            panel.orderFrontRegardless()   // keep him above the overlay
            debugPanel = p
            pet.say("Debug: asking Finder...", duration: 2)
            pet.refreshFolders(announce: true)
        } else {
            debugPanel?.orderOut(nil)
            debugPanel = nil
        }
        statusItem.menu = buildMenu()
    }
    @objc private func menuHide() {
        if !pet.tryHide() && pet.canAct { pet.say("Nowhere to hide! Open a window near the Dock.", duration: 2.5) }
    }
    @objc private func menuToggleChatter() {
        pet.chatterEnabled.toggle()
        pet.say(pet.chatterEnabled ? "Yay, talking!" : "Okay, I'll be quiet. Mostly.", duration: 2.2)
        statusItem.menu = buildMenu()
    }
    @objc private func menuQuit() { NSApp.terminate(nil) }

    @objc private func menuToggleBall() { toggleToy(.ball) }
    @objc private func menuToggleTrampoline() { toggleToy(.trampoline) }
    @objc private func menuPlayBall() { pet.playBall() }
    @objc private func menuPlayTrampoline() { pet.playTrampoline() }

    @objc private func menuPickHat(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let hat = Hat(rawValue: raw) else { return }
        pet.hat = hat
        defaults.set(hat.rawValue, forKey: "hat")
        pet.happyTime = 1.2
        pet.say(hat.reaction, duration: 2.4)
        statusItem.menu = buildMenu()
    }

    @objc private func menuToggleAgent() {
        pet.agent.toggle()
        defaults.set(pet.agent, forKey: "agent")
        pet.say(pet.agent ? "*puts on shades* Agent Stix, on the case." : "Mission complete. Back to civilian life.", duration: 2.6)
        statusItem.menu = buildMenu()
    }
}

@main
@MainActor
struct StixMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)   // no Dock icon
        app.run()
    }
}
