// Platypal — a turquoise platypus that lives on your Mac desktop.
//
// Build:  ./build.sh        (needs Xcode Command Line Tools: `xcode-select --install`)
// Run:    open Platypal.app
//
// Controls
//   • Click        → poke him
//   • Double-click → backflip
//   • Drag         → pick him up; let go mid-swing to throw him
//   • Right-click  → menu (also in the menu bar, paw icon)
//   • Leave the cursor resting near his face → boop

import Cocoa

// MARK: - Tunables

let kWinW: CGFloat = 320
let kWinH: CGFloat = 290
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
}

extension Array {
    var pick: Element { self[Int.random(in: 0..<count)] }
}

// MARK: - Things he says

enum Lines {
    static let chatter = [
        "Fun fact: I lay eggs. Yes, really. I'm a mammal AND I lay eggs.",
        "I can sense electric fields with my bill. Your laptop is LOUD.",
        "Platypuses glow under UV light. I just glow all the time.",
        "I'm not a duck. I'm not a beaver. I'm a whole vibe.",
        "I store fat in my tail. That's why it's so magnificent.",
        "Is it snack time? It feels like snack time.",
        "You've been at it a while. Stretch break?",
        "Remember to drink some water!",
        "Have you saved your work recently? Just asking.",
        "Nice cursor. Very pointy.",
        "This dock makes a great sidewalk.",
        "*hums quietly*",
        "Hey. You're doing great.",
        "I could really go for a swim right now.",
        "Quack? No. Wait. Not quack. I don't know what I say.",
        "I hunt with my eyes closed. Show-off move, I know.",
        "No stomach, no problem.",
        "If you need me, I'll be down here. Being turquoise.",
    ]
    static let poke    = ["Hey!", "Hi there!", "That tickles!", "What's up?", "*happy chirp*", "Yes? Hello?", "Present!"]
    static let held    = ["Wheee!", "Put me doooown!", "I can see my house from here!", "Hey! Paws off! ...okay, fine."]
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

    static func greeting() -> String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12:  return "Good morning! Coffee first, then greatness."
        case 12..<18: return "Good afternoon! I'm here to help. By walking around."
        case 18..<23: return "Good evening! Mind if I hang out?"
        default:      return "It's late! I'll keep you company."
        }
    }

    static func randomChatter() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        if Double.random(in: 0..<1) < 0.2 {
            switch hour {
            case 5..<11:  return "Morning brain is loading... please wait."
            case 13..<16: return "Afternoon slump? I believe in you."
            case 18..<23: return "Evening already? Time flies when you're a platypus."
            case 23..<24, 0..<5: return "It's pretty late... bed soon, maybe?"
            default: break
            }
        }
        return chatter.pick
    }
}

// MARK: - The platypus (state + behaviour)

enum Activity: Equatable {
    case idle, walk, run, chase, stare, sleep, dance, boop, dizzy, held, airborne
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

    // Speech
    var speech: String?
    var speechTime: Double = 0
    var speechDuration: Double = 0
    var nextChatter: Double = 30
    var chatterEnabled = true

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
        case .held, .chase: return .wide
        case .dance, .boop: return .happy
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

    func saySomething() { say(Lines.randomChatter()) }

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
        if speech == nil || Bool.random() { say(Lines.held.pick, duration: 2.2) }
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
    }

    private func land(impact: CGFloat) {
        onGround = true
        vel = .zero
        spinSpeed = 0
        squash = max(0.55, 1 - impact / 3000)
        if activity == .airborne {
            if willBeDizzy {
                set(.dizzy, duration: 2.8)
                say(Lines.dizzy.pick)
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
            (5,  { self.hop() }),
            (6,  { self.chase() }),
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

        let a = area
        let minX = a.minX + kEdge, maxX = a.maxX - kEdge, ground = a.minY

        // Blinking
        nextBlink -= dt
        if blink > 0 { blink -= dt }
        if nextBlink <= 0 { blink = 0.13; nextBlink = .random(in: 2...6) }

        // Eyes follow the cursor
        let eye = CGPoint(x: pos.x + 44 * facing, y: pos.y + 46)
        let dx = mouse.x - eye.x, dy = mouse.y - eye.y
        let len = max(1, hypot(dx, dy))
        let reach = min(1, len / 120)
        look = CGVector(dx: dx / len * reach, dy: dy / len * reach)

        // Is the user around?
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
        if chatterEnabled && speech == nil && activity != .sleep && activity != .held {
            nextChatter -= dt
            if nextChatter <= 0 { say(Lines.randomChatter()) }
        }

        squash += (1 - squash) * min(1, fdt * 10)

        // Being carried: dangle and flail
        if activity == .held {
            spin += (heldSwingTarget - spin) * min(1, fdt * 8)
            heldSwingTarget *= max(0, 1 - fdt * 4)
            return
        }

        // In the air: ballistic physics with wall/floor bounces
        if !onGround {
            vel.dy -= kGravity * fdt
            pos.x += vel.dx * fdt
            pos.y += vel.dy * fdt
            spin += spinSpeed * fdt
            if pos.x < minX { pos.x = minX; bonk(); vel.dx = abs(vel.dx) * 0.5; spinSpeed *= -0.6 }
            if pos.x > maxX { pos.x = maxX; bonk(); vel.dx = -abs(vel.dx) * 0.5; spinSpeed *= -0.6 }
            if pos.y > a.maxY - 110 { pos.y = a.maxY - 110; vel.dy = -abs(vel.dy) * 0.3 }
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
        let head = CGPoint(x: pos.x + 40 * facing, y: pos.y + 42)
        if !moved && hypot(mouse.x - head.x, mouse.y - head.y) < 80 { cursorIdle += dt } else if cursorIdle > 0 { cursorIdle = 0 }
        if cursorIdle < 0 { cursorIdle += dt }   // cooldown
        if cursorIdle > 1.4 && [Activity.idle, .stare, .walk].contains(activity) {
            cursorIdle = -6
            facing = mouse.x > pos.x ? 1 : -1
            set(.boop, duration: 0.6)
            say("Boop!", duration: 1.4)
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
            if abs(targetX - pos.x) < speed * fdt + 1 || pos.x <= minX || pos.x >= maxX || activityTime > activityDuration {
                set(.idle, duration: .random(in: 1...3))
            }

        case .chase:
            let dir: CGFloat = mouse.x > pos.x ? 1 : -1
            facing = dir
            if abs(mouse.x - pos.x) > 70 {
                pos.x += dir * 300 * fdt
                walkPhase += fdt * 20
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

        case .boop, .dizzy:
            if activityTime > activityDuration { set(.idle, duration: 1.5) }

        case .airborne, .held:
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

        // Ground shadow (shrinks as he goes up)
        let height = max(0, p.pos.y - p.area.minY)
        let s = max(0.3, 1 - height / 400)
        ctx.setFillColor(NSColor.black.withAlphaComponent(0.16 * s).cgColor)
        ctx.fillEllipse(in: CGRect(x: cx - 46 * s, y: kFootY - height - 5, width: 92 * s, height: 10))

        // The platypus itself
        ctx.saveGState()
        ctx.translateBy(x: cx, y: kFootY)
        ctx.scaleBy(x: p.facing, y: 1)
        ctx.translateBy(x: 0, y: 30)
        ctx.rotate(by: p.spin)
        ctx.translateBy(x: 0, y: -30)
        ctx.scaleBy(x: 1 + (1 - p.squash) * 0.7, y: p.squash)
        drawPlatypus(ctx)
        ctx.restoreGState()

        drawEffects(ctx, cx: cx)
        drawBubble(ctx, cx: cx)
    }

    /// Local coordinates: feet at y = 0, facing +x.
    private func drawPlatypus(_ ctx: CGContext) {
        let p = pet
        let t = CGFloat(p.time)
        let moving = [Activity.walk, .run, .chase].contains(p.activity)
        let sleeping = p.activity == .sleep
        let held = p.activity == .held
        let airborne = !p.onGround && !held

        var bob = sin(t * 2.2) * 1.0                          // breathing
        if moving { bob = abs(sin(p.walkPhase)) * 3 }
        if sleeping { bob = -7 + sin(t * 1.3) * 1.2 }
        if p.activity == .boop {
            let k = CGFloat(min(1, p.activityTime / p.activityDuration))
            ctx.translateBy(x: sin(k * .pi) * 16, y: 0)       // lunge forward
        }
        if p.activity == .dance {
            ctx.translateBy(x: 0, y: 30)
            ctx.rotate(by: sin(t * 14) * 0.08)
            ctx.translateBy(x: 0, y: -30)
        }

        // --- Legs (behind the body) ---
        func leg(_ hipX: CGFloat, phase: CGFloat, far: Bool) {
            let hip = CGPoint(x: hipX, y: 18 + bob)
            var foot: CGPoint
            if held {
                foot = CGPoint(x: hipX + sin(t * 22 + phase) * 7, y: hip.y - 16)
            } else if airborne {
                foot = CGPoint(x: hipX + (far ? -7 : 7), y: hip.y - 12)
            } else if sleeping {
                foot = CGPoint(x: hipX + 8, y: 2)
            } else if moving {
                let ph = p.walkPhase + phase
                foot = CGPoint(x: hipX + sin(ph) * 9, y: max(0, cos(ph)) * 5)
            } else if p.activity == .dance {
                foot = CGPoint(x: hipX + sin(t * 14 + phase) * 3, y: 0)
            } else {
                foot = CGPoint(x: hipX, y: 0)
            }
            ctx.setLineCap(.round)
            ctx.move(to: hip); ctx.addLine(to: CGPoint(x: foot.x, y: foot.y + 3))
            ctx.setStrokeColor(Palette.outline.cgColor); ctx.setLineWidth(12); ctx.strokePath()
            ctx.move(to: hip); ctx.addLine(to: CGPoint(x: foot.x, y: foot.y + 3))
            ctx.setStrokeColor((far ? Palette.tail : Palette.bodyShade).cgColor); ctx.setLineWidth(8); ctx.strokePath()
            // webbed foot
            ctx.setFillColor(Palette.outline.cgColor)
            ctx.fillEllipse(in: CGRect(x: foot.x - 6, y: foot.y - 1.5, width: 19, height: 9))
            ctx.setFillColor(Palette.bill.cgColor)
            ctx.fillEllipse(in: CGRect(x: foot.x - 4.5, y: foot.y, width: 16, height: 6))
            ctx.setStrokeColor(Palette.billLight.cgColor); ctx.setLineWidth(1)
            for i in 0..<2 {
                let x = foot.x + 4 + CGFloat(i) * 4
                ctx.move(to: CGPoint(x: x, y: foot.y + 1)); ctx.addLine(to: CGPoint(x: x + 2, y: foot.y + 4))
            }
            ctx.strokePath()
        }
        leg(-20, phase: .pi, far: true)
        leg(26, phase: 0, far: true)
        leg(-26, phase: 0, far: false)
        leg(20, phase: .pi, far: false)

        // --- Tail: flat paddle with a crosshatch texture ---
        ctx.saveGState()
        ctx.translateBy(x: -40, y: 24 + bob)
        var wag = sin(t * (moving ? 10 : 2.5)) * (moving ? 0.18 : 0.1) - 0.08
        if held { wag += sin(t * 12) * 0.3 }
        if p.activity == .dance { wag += sin(t * 14) * 0.25 }
        ctx.rotate(by: wag)
        let tail = CGPath(ellipseIn: CGRect(x: -50, y: -11, width: 58, height: 22), transform: nil)
        ctx.addPath(tail); ctx.setStrokeColor(Palette.outline.cgColor); ctx.setLineWidth(5); ctx.strokePath()
        ctx.addPath(tail); ctx.setFillColor(Palette.tail.cgColor); ctx.fillPath()
        ctx.addPath(tail); ctx.clip()
        ctx.setStrokeColor(Palette.body.withAlphaComponent(0.3).cgColor); ctx.setLineWidth(1.2)
        for i in stride(from: CGFloat(-60), to: 20, by: 8) {
            ctx.move(to: CGPoint(x: i, y: -12)); ctx.addLine(to: CGPoint(x: i + 14, y: 12))
            ctx.move(to: CGPoint(x: i + 14, y: -12)); ctx.addLine(to: CGPoint(x: i, y: 12))
        }
        ctx.strokePath()
        ctx.restoreGState()

        // --- Body + head as one silhouette (outline first, then fill, so no seam) ---
        let bodyRect = CGRect(x: -48, y: 8 + bob, width: 96, height: 44)
        let headRect = CGRect(x: 18, y: 21 + bob, width: 40, height: 38)
        let sil = CGMutablePath()
        sil.addEllipse(in: bodyRect)
        sil.addEllipse(in: headRect)
        ctx.addPath(sil); ctx.setStrokeColor(Palette.outline.cgColor); ctx.setLineWidth(5); ctx.strokePath()
        ctx.addPath(sil); ctx.setFillColor(Palette.body.cgColor); ctx.fillPath()

        ctx.saveGState()
        ctx.addPath(sil); ctx.clip()
        ctx.setFillColor(Palette.belly.cgColor)
        ctx.fillEllipse(in: CGRect(x: -32, y: 2 + bob, width: 80, height: 22))
        ctx.setFillColor(NSColor.white.withAlphaComponent(0.22).cgColor)
        ctx.fillEllipse(in: CGRect(x: -34, y: 38 + bob, width: 46, height: 10))
        ctx.restoreGState()

        // Cheek blush
        ctx.setFillColor(Palette.blush.cgColor)
        ctx.fillEllipse(in: CGRect(x: 32, y: 31 + bob, width: 11, height: 6))

        // --- Bill: upper + hinged lower jaw that flaps when he talks ---
        ctx.saveGState()
        ctx.translateBy(x: 51, y: 37 + bob)
        ctx.rotate(by: 0.06)
        ctx.saveGState()
        ctx.rotate(by: -p.mouthOpen * 0.32)
        let lower = CGPath(roundedRect: CGRect(x: 0, y: -8, width: 30, height: 9), cornerWidth: 4.5, cornerHeight: 4.5, transform: nil)
        ctx.addPath(lower); ctx.setFillColor(Palette.bill.cgColor); ctx.fillPath()
        ctx.addPath(lower); ctx.setStrokeColor(Palette.outline.cgColor); ctx.setLineWidth(2); ctx.strokePath()
        ctx.restoreGState()
        let upper = CGPath(roundedRect: CGRect(x: 0, y: -3, width: 37, height: 12), cornerWidth: 6, cornerHeight: 6, transform: nil)
        ctx.addPath(upper); ctx.setFillColor(Palette.billLight.cgColor); ctx.fillPath()
        ctx.addPath(upper); ctx.setStrokeColor(Palette.outline.cgColor); ctx.setLineWidth(2); ctx.strokePath()
        ctx.setFillColor(Palette.outline.cgColor)
        ctx.fillEllipse(in: CGRect(x: 26, y: 4, width: 2.4, height: 2.4))
        ctx.fillEllipse(in: CGRect(x: 30.5, y: 4, width: 2.4, height: 2.4))
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.25).cgColor); ctx.setLineWidth(1.5)
        ctx.move(to: CGPoint(x: 6, y: 6.5)); ctx.addLine(to: CGPoint(x: 20, y: 6.5)); ctx.strokePath()
        ctx.restoreGState()

        // --- Eye ---
        let e = CGPoint(x: 41, y: 47 + bob)
        ctx.setLineCap(.round)
        switch p.eyes {
        case .open, .wide:
            let r: CGFloat = p.eyes == .wide ? 6.8 : 5.8
            ctx.setFillColor(NSColor.white.cgColor)
            ctx.fillEllipse(in: CGRect(x: e.x - r, y: e.y - r, width: r * 2, height: r * 2))
            ctx.setStrokeColor(Palette.outline.cgColor); ctx.setLineWidth(1.6)
            ctx.strokeEllipse(in: CGRect(x: e.x - r, y: e.y - r, width: r * 2, height: r * 2))
            let pr: CGFloat = p.eyes == .wide ? 2.8 : 3.5
            let pc = CGPoint(x: e.x + p.look.dx * p.facing * 2.3, y: e.y + p.look.dy * 2.3)
            ctx.setFillColor(Palette.outline.cgColor)
            ctx.fillEllipse(in: CGRect(x: pc.x - pr, y: pc.y - pr, width: pr * 2, height: pr * 2))
            ctx.setFillColor(NSColor.white.cgColor)
            ctx.fillEllipse(in: CGRect(x: pc.x + 0.3, y: pc.y + 0.6, width: 2.2, height: 2.2))
        case .closed:
            ctx.move(to: CGPoint(x: e.x - 5, y: e.y))
            ctx.addQuadCurve(to: CGPoint(x: e.x + 5, y: e.y), control: CGPoint(x: e.x, y: e.y - 4))
            ctx.setStrokeColor(Palette.outline.cgColor); ctx.setLineWidth(2.2); ctx.strokePath()
        case .happy:
            ctx.move(to: CGPoint(x: e.x - 5, y: e.y - 2))
            ctx.addQuadCurve(to: CGPoint(x: e.x + 5, y: e.y - 2), control: CGPoint(x: e.x, y: e.y + 5))
            ctx.setStrokeColor(Palette.outline.cgColor); ctx.setLineWidth(2.2); ctx.strokePath()
        case .dizzy:
            ctx.move(to: CGPoint(x: e.x - 4, y: e.y - 4)); ctx.addLine(to: CGPoint(x: e.x + 4, y: e.y + 4))
            ctx.move(to: CGPoint(x: e.x - 4, y: e.y + 4)); ctx.addLine(to: CGPoint(x: e.x + 4, y: e.y - 4))
            ctx.setStrokeColor(Palette.outline.cgColor); ctx.setLineWidth(2.2); ctx.strokePath()
        }
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
                let x = cx + p.facing * (28 + ph * 26) - 6
                glyph(i % 2 == 0 ? "z" : "Z",
                      at: CGPoint(x: x, y: kFootY + 48 + ph * 50),
                      size: 10 + ph * 9,
                      color: Palette.outline.withAlphaComponent(sin(ph * .pi) * 0.8))
            }
        case .dance:
            for i in 0..<2 {
                let ph = (t * 0.7 + CGFloat(i) / 2).truncatingRemainder(dividingBy: 1)
                let side: CGFloat = i == 0 ? -1 : 1
                glyph(i == 0 ? "♪" : "♫",
                      at: CGPoint(x: cx + side * (44 + sin(ph * 6) * 6) - 7, y: kFootY + 50 + ph * 55),
                      size: 18,
                      color: Palette.tail.withAlphaComponent(sin(ph * .pi)))
            }
        case .dizzy:
            let c = CGPoint(x: cx + p.facing * 36, y: kFootY + 66)
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

        let anchor = CGPoint(x: cx + pet.facing * 30, y: kFootY + 74)
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

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Drop in from the top of the screen
        let vf = (NSScreen.main ?? NSScreen.screens[0]).visibleFrame
        pet.pos = CGPoint(x: .random(in: (vf.minX + 200)...(max(vf.minX + 201, vf.maxX - 200))), y: vf.maxY - 120)
        pet.facing = Bool.random() ? 1 : -1

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
            if let img = NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: "Platypal") {
                img.isTemplate = true
                button.image = img
            } else {
                button.title = "🐾"
            }
        }
        statusItem.menu = buildMenu()

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

        // The window is click-through everywhere except right over the platypus.
        let f = panel.frame
        let local = CGPoint(x: mouse.x - f.minX, y: mouse.y - f.minY)
        let hitBox = CGRect(x: f.width / 2 - 90, y: kFootY - 6, width: 180, height: 78)
        panel.ignoresMouseEvents = !(hitBox.contains(local) || view.mouseIsDown)

        view.needsDisplay = true
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
        menu.addItem(.separator())
        let chatty = NSMenuItem(title: "Chatty", action: #selector(menuToggleChatter), keyEquivalent: "")
        chatty.target = self
        chatty.state = pet.chatterEnabled ? .on : .off
        menu.addItem(chatty)
        menu.addItem(.separator())
        add("Quit Platypal", #selector(menuQuit), key: "q")
        return menu
    }

    @objc private func menuSay()   { pet.saySomething() }
    @objc private func menuCome()  { pet.come(to: NSEvent.mouseLocation.x) }
    @objc private func menuFlip()  { pet.backflip() }
    @objc private func menuDance() { pet.dance() }
    @objc private func menuNap()   { pet.nap() }
    @objc private func menuToggleChatter() {
        pet.chatterEnabled.toggle()
        pet.say(pet.chatterEnabled ? "Yay, talking!" : "Okay, I'll be quiet. Mostly.", duration: 2.2)
        statusItem.menu = buildMenu()
    }
    @objc private func menuQuit() { NSApp.terminate(nil) }
}

@main
@MainActor
struct PlatypalMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)   // no Dock icon
        app.run()
    }
}
