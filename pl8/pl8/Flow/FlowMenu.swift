import RealityKit
import SwiftUI
import PlateKit

/// The menu's own UI (labels are the stage's).
@MainActor @Observable
final class MenuUI {
    var active: String?
}

/// A gym's box that opens into a room (gymRoomModel's open and wave).
@MainActor
final class FlowGymRoom {
    let entity: Entity
    let isAdd: Bool
    private let frontPivot: Entity?, rightPivot: Entity?, lid: Entity?
    private let fading: [Entity]
    let items: [String: Entity]
    private let cloth: ModelEntity?
    private let clothBase: LowPolyMesh?
    private weak var flow: Flow?
    static let size: Float = 1.15, wall: Float = 0.04

    init(flow: Flow, gym: Gym?) {
        self.flow = flow
        if let gym {
            entity = flow.build(FlowProps.gymRoom(name: gym.name, unit: gym.unit, plates: gym.plateSizes))
            isAdd = false
        } else {
            entity = flow.build(FlowProps.addCube())
            isAdd = true
        }
        frontPivot = entity.findEntity(named: "frontPivot")
        rightPivot = entity.findEntity(named: "rightPivot")
        lid = entity.findEntity(named: "lid")
        fading = [frontPivot, rightPivot, lid].compactMap { $0 }
        var found: [String: Entity] = [:]
        for name in ["flag", "bars", "plates", "bell"] { found[name] = entity.findEntity(named: name) }
        items = found
        cloth = entity.findEntity(named: "flagCloth")?.children.first as? ModelEntity
        clothBase = cloth.flatMap { model in flow.shaded.first { $0.model === model }?.part.mesh }
        open(0)
    }

    /// 0 closed … 1 open: the lid lifts off, the front and right walls fall outward and fade, then the things
    /// inside pop up one after another.
    func open(_ k: Float) {
        guard !isAdd, let flow else { return }
        let s = Self.size, th = Self.wall
        let e = min(1, max(0, k)), a = min(1, e / 0.7), fall = a * a * (3 - 2 * a)
        frontPivot?.orientation = simd_quatf(angle: fall * .pi / 2, axis: [1, 0, 0])
        rightPivot?.orientation = simd_quatf(angle: -fall * .pi / 2, axis: [0, 0, 1])
        lid?.position.y = s - th / 2 + fall * 0.9
        lid?.orientation = simd_quatf(angle: fall * 0.4, axis: [0, 0, 1])
        let fade = max(0, 1 - max(0, (e - 0.35) / 0.4))
        for part in fading {
            flow.setOpacity(fade, under: part)
            part.isEnabled = fade > 0.01
        }
        for (i, key) in ["flag", "bars", "plates", "bell"].enumerated() {
            let q = min(1, max(0, (e - 0.45 - Float(i) * 0.08) / 0.35))
            items[key]?.scale = SIMD3(repeating: max(0.0001, Float(Ease.outBack(Double(q), 1.6))))
        }
    }

    /// The flag hangs from its top edge: the free bottom edge moves most, ripples run across.
    func wave(_ t: Float) {
        guard let cloth, let base = clothBase else { return }
        let fh: Float = 0.35
        var mesh = base
        mesh.positions = base.positions.map { p in
            let dn = -p.y / fh
            return SIMD3(p.x + sin(t * 2.6 + p.x * 9) * 0.006 * dn, p.y,
                         (sin(t * 2.6 + p.x * 9 - dn * 2) * 0.028 + sin(t * 1.3 + p.x * 4) * 0.012) * dn)
        }
        if let resource = try? Flow.meshResource(mesh, palette: false) { cloth.model?.mesh = resource }
    }
}

extension Flow {
    // MARK: - The menu (flMenu)

    func stepMenu() {
        mode = .menu
        editOne = false
        let menuCam = FlowCam(position: [0, 1.4, 7.2], target: [0, 0.55, 0], fov: 35)
        cam = menuCam
        let spacing: Float = 1.9
        let ui = MenuUI()
        menuUI = ui
        let keys = ["train", "prs", "gym"], titles = ["Train", "My PRs", "Gym"]
        var wrappers: [Entity] = [], models: [Entity] = [], shadows: [Entity] = []
        var position = menuPosition, velocity: Float = 0, index = Int(position.rounded()), dragging = false
        var active: Int?, k: Float = 0, busy = false

        // Train: the board shows the last session.
        let board = makeBoard()
        board.entity.scale = SIMD3(repeating: 0.62)
        board.canvas?.draw(data.boardLines)
        var boardHasPlan = data.workout != nil
        // My PRs: the notebook, and the pencil that appears when it opens.
        let book = build(FlowProps.notebook(title: "MY PRs", rows: data.prRows))
        book.position.y = 0.8
        book.orientation = simd_quatf(angle: -0.25, axis: [1, 0, 0])
        let hinge = book.findEntity(named: "hinge")
        let pen = build(FlowProps.pencil())
        pen.position = [0.55, 0.36, 0.34]
        pen.orientation = Flow.quaternion([0.5, 0, -0.95])
        pen.scale = SIMD3(repeating: 0.0001)
        // Gym: the current gym's room; inside, the row of gyms with an empty cube at the end.
        let gyms = data.gyms
        var current = data.gymIndex
        let rooms: [FlowGymRoom] = gyms.map { FlowGymRoom(flow: self, gym: $0) } + [FlowGymRoom(flow: self, gym: nil)]
        var room = rooms[current]

        for (i, model) in [board.entity, book, room.entity].enumerated() {
            let wrapper = Entity()
            wrapper.addChild(model)
            wrapper.position.x = (Float(i) - position) * spacing
            let shadow = softShadow(0.7)
            shadow.scale = [1, 0.6, 1]
            wrapper.addChild(shadow)
            add(wrapper)
            wrappers.append(wrapper); models.append(model); shadows.append(shadow)
        }
        wrappers[1].addChild(pen)
        for (j, other) in rooms.enumerated() where j != current {
            other.open(1)
            other.entity.scale = SIMD3(repeating: 0.0001)
            wrappers[2].addChild(other.entity)
        }
        let right = SIMD3<Float>(0.794, 0, -0.607), roomSpacing: Float = 2.4
        var rowPosition = Float(current), rowTarget = Float(current), rowDragging = false

        let camFor = { (i: Int) -> FlowCam in
            let c = wrappers[i].position
            switch keys[i] {
            case "gym": return FlowCam(position: c + [3.9, 3.6, 5.1], target: c + [0, 0.42, 0], fov: 35)
            case "prs": return FlowCam(position: c + [0, 1.2, 6.5], target: c + [0, 0.74, 0], fov: 35)
            default: return FlowCam(position: c + [0, 1.2, 5.2], target: c + [0, 0.82, 0], fov: 35)
            }
        }
        var labelOpacity: [Double] = [1, 1, 1]
        let applyK = { [weak self] in
            guard let self else { return }
            let e = k * k * (3 - 2 * k)
            guard let a = active else { self.cam = menuCam; return }
            let target = camFor(a)
            self.cam = FlowCam(position: menuCam.position + (target.position - menuCam.position) * e,
                               target: menuCam.target + (target.target - menuCam.target) * e, fov: 35)
            for i in 0..<3 { labelOpacity[i] = Double((i == a ? 1 : 0.25) * (1 - e)) }
            switch keys[a] {
            case "prs":
                hinge?.orientation = simd_quatf(angle: -2.95 * e, axis: [0, 1, 0])
                book.orientation = Flow.quaternion([-0.25 + 0.15 * e, 0.18 * (1 - e), 0])
                book.scale = SIMD3(repeating: 1 - 0.3 * e)
                book.position.x = 0.37 * e
                pen.scale = SIMD3(repeating: max(0.0001, Float(Ease.outBack(Double(min(1, max(0, (k - 0.4) / 0.6))), 1.4))))
            case "gym":
                room.open(k)
            default:
                models[a].orientation = simd_quatf(angle: 0, axis: [0, 1, 0])
            }
        }
        let activate = { [weak self] (i: Int, instant: Bool) in
            guard let self else { return }
            active = i
            self.menuActive = keys[i]
            ui.active = keys[i]
            dragging = false
            velocity = 0
            position = Float(i)
            self.menuPosition = position
            if instant { k = 1; applyK(); return }
            let k0 = k
            busy = true
            self.click(0.9)
            self.anim(keys[i] == "gym" ? 1.1 : 0.6, { u in k = k0 + (1 - k0) * Float(Ease.outCubic(u)); applyK() }, done: { [weak self] in
                busy = false
                if keys[i] == "gym" { self?.sparkles(at: wrappers[2].position + [0, 0.9, 0.3], count: 5, spread: 1) }
            })
        }
        let deactivate = { [weak self] (from: Float) in
            guard let self else { return }
            busy = true
            self.anim(0.45, { u in k = from * Float(pow(1 - u, 3)); applyK() }, done: {
                k = 0
                applyK()
                active = nil
                self.menuActive = nil
                ui.active = nil
                busy = false
                labelOpacity = [1, 1, 1]
            })
        }
        // First time: the items pop in; back from an edit: the item is already awake.
        if let back = menuActive.flatMap({ keys.firstIndex(of: $0) }) {
            activate(back, true)
        } else {
            for (i, wrapper) in wrappers.enumerated() { popIn(wrapper, delay: 0.12 + Double(i) * 0.09) }
        }

        let settleGym = { [weak self] in
            guard let self, !busy else { return }
            let j = Int(rowTarget.rounded())
            if j != current && j < gyms.count {
                self.data.makeCurrent(j)
                current = j
                rooms[j].open(1)
                room = rooms[j]
                self.buzz(.selection)
            }
        }

        tick = { [weak self] dt, t in
            guard let self else { return }
            if active == nil {
                if !dragging {
                    position += velocity * dt
                    velocity *= exp(-dt * 5)
                    position = max(-0.3, min(2.3, position))
                    if abs(velocity) < 1.5 { position += (max(0, min(2, position.rounded())) - position) * (1 - exp(-dt * 10)) }
                }
                let i0 = max(0, min(2, Int(position.rounded())))
                if i0 != index { index = i0; self.buzz(.selection) }
                self.menuPosition = position
            }
            var labels: [FlowLabel] = []
            for i in 0..<3 {
                let d = Float(i) - position, ad = abs(d)
                let others = active != nil && active != i ? k * k * (3 - 2 * k) : 0
                wrappers[i].position.x = d * spacing + (d == 0 ? 0 : (d > 0 ? 1 : -1)) * others * 1.6
                wrappers[i].position.z = -min(1, ad) * 0.6
                let calm: Float = active == i ? 1 - min(1, k * 1.5) : 1
                let sway = 0.25 * sin(Float(t) * 0.6 + Float(i)) * (ad < 0.5 ? 1 : 0.4)
                switch keys[i] {
                case "gym": room.entity.orientation = simd_quatf(angle: sway * calm, axis: [0, 1, 0])
                case "prs": if active != i { book.orientation = Flow.quaternion([-0.25, 0.18 + sway, 0]) }
                default: models[i].orientation = simd_quatf(angle: sway * calm, axis: [0, 1, 0])
                }
                if let point = self.project([wrappers[i].position.x, -0.45, wrappers[i].position.z]) {
                    let opacity = active == nil ? max(0.25, 1 - Double(ad) * 0.75) : labelOpacity[i]
                    labels.append(FlowLabel(id: i, text: titles[i], point: point, opacity: opacity))
                }
            }
            self.labels = labels
            // The row of gyms.
            let show = active == 2 ? k * k * (3 - 2 * k) : 0
            if active != 2 { rowTarget = Float(current) }
            if !rowDragging { rowPosition += (rowTarget - rowPosition) * (1 - exp(-dt * 9)) }
            for (j, r) in rooms.enumerated() {
                r.entity.position = right * (Float(j) - rowPosition) * roomSpacing
                if r !== room {
                    r.entity.scale = SIMD3(repeating: max(0.0001, show))
                    r.entity.orientation = simd_quatf(angle: 0, axis: [0, 1, 0])
                }
                if show > 0.5 { r.wave(Float(t) + Float(j)) }
            }
            if !rowDragging && abs(rowTarget - rowPosition) < 0.02 { settleGym() }
            shadows[2].position.x = room.entity.position.x
            shadows[2].position.z = room.entity.position.z
            shadows[2].isEnabled = abs(rowPosition - Float(current)) < 0.5
        }

        // What each awake item does.
        let edit = { [weak self] (step: Step) in
            guard let self else { return }
            self.buzz(.light)
            self.checkSound()
            self.menuActive = "gym"
            self.editOne = true
            self.mode = .gym
            busy = true
            self.panTo(step)
        }
        let trainStart = { [weak self] in
            guard let self, let plan = self.data.startSession() else { return }
            busy = true
            self.buzz(.light)
            self.checkSound()
            self.plan = plan
            self.setIndex = 0
            self.doneSets = []
            self.collected = []
            self.mode = .menu
            self.again = true
            let cy = 1.45 * Float(0.62), c0 = wrappers[0].position
            let p0 = self.cam.position, t0 = self.cam.target
            let p1 = c0 + [0.1, cy, 0.5], t1 = c0 + [0, cy, 0]
            self.labels = []
            self.anim(0.9, { u in
                let e = Float(Ease.inOutCubic(u))
                self.cam.position = p0 + (p1 - p0) * e
                self.cam.target = t0 + (t1 - t0) * e
            }, done: { [weak self] in
                self?.menuActive = "train"
                self?.go(.kit)
            })
        }
        let upload = { [weak self] in
            guard let self else { return }
            self.buzz(.light)
            self.checkSound()
            self.pickPhoto(.workout, reading: "Reading your workout…", read: { [weak self] image in
                await self?.data.readWorkout(image) ?? false
            }, then: { [weak self] ok in
                guard let self, ok else { return }
                board.canvas?.draw(self.data.boardLines)
                boardHasPlan = true
                self.shine([board.entity], duration: 0.6)
                self.sparkles(at: wrappers[0].position + [0, 0.95, 0.3], count: 5, spread: 0.9)
            })
        }
        let prUpload = { [weak self] in
            guard let self else { return }
            self.buzz(.light)
            self.checkSound()
            self.pickPhoto(.prs, reading: "Reading your PRs…", read: { [weak self] image in
                await self?.data.readPRs(image) ?? false
            }, then: { [weak self] ok in
                guard let self, ok else { return }
                self.repaint(book, part: "page", with: .notebookPage(self.data.prRows))
                self.shine([book], duration: 0.7)
                self.sparkles(at: wrappers[1].position + [0.4, 0.9, 0.4], count: 5, spread: 1)
            })
        }
        let askDelete = { [weak self] in
            guard let self else { return }
            self.buzz(.warning)
            let name = self.data.gym.name.isEmpty ? "this gym" : self.data.gym.name
            if self.data.gyms.count <= 1 {
                self.alert = FlowAlert(title: "Can’t delete \(name)", message: "You need at least one gym.", buttons: [.init(label: "OK")])
                return
            }
            self.alert = FlowAlert(title: "Delete \(name)?", message: "Its plates and bar settings will be removed.", buttons: [
                .init(label: "Cancel"),
                .init(label: "Delete", destructive: true, action: { [weak self] in
                    guard let self else { return }
                    self.data.deleteGym(at: current)
                    self.buzz(.success)
                    self.menuActive = "gym"
                    self.go(.menu)
                }),
            ])
        }
        let newGym = { [weak self] in
            guard let self else { return }
            self.buzz(.light)
            self.checkSound()
            busy = true
            self.data.addGym()
            self.menuActive = "gym"
            self.editOne = false
            self.mode = .gym
            self.panTo(.name)
        }
        let pointsPerItem = 390 * spacing / (7.2 * 0.2914 * 1.15)

        hit = { [weak self] point in
            guard let self else { return nil }
            if busy { return FlowDrag(move: nil, up: nil) }
            if let a = active {
                // A gesture on an awake item: decided by what's under the finger and which way it goes.
                var mode: String?
                let onBoard = keys[a] == "train" && board.face.map { self.touches(point, $0) } == true
                var row0 = rowPosition
                var hold: Int?
                if keys[a] == "gym", Int(rowTarget.rounded()) < gyms.count, self.touches(point, room.entity) {
                    hold = self.later(0.6) { if mode == nil { mode = "held"; askDelete() } }
                }
                return FlowDrag(move: { [weak self] p in
                    guard let self else { return }
                    let dx = p.x - point.x, dy = p.y - point.y
                    if mode == nil {
                        guard hypot(dx, dy) >= 10 else { return }
                        self.cancelTimer(hold)
                        if keys[a] == "gym" && abs(dx) > abs(dy) {
                            mode = "gyms"; rowDragging = true; row0 = rowPosition
                        } else if -dy > abs(dx) * (onBoard && boardHasPlan ? 2.6 : 1.3) {
                            mode = "back"
                        } else if onBoard && boardHasPlan {
                            mode = "wipe"
                        } else {
                            mode = "none"
                        }
                    }
                    switch mode {
                    case "back":
                        // It settles back into the menu with your finger.
                        k = 1 - Float(max(0, min(1, (point.y - p.y - 10) / (300 * self.layoutScale))))
                        applyK()
                    case "gyms":
                        rowPosition = max(-0.25, min(Float(rooms.count) - 0.75, row0 - Float(dx / self.layoutScale) / 420))
                    case "wipe":
                        if self.wipeBoard(board, at: p) { boardHasPlan = false; self.data.wipeBoard() }
                        if Double.random(in: 0..<1) < 0.18 { self.click(2.6); self.buzz(.selection) }
                    default: break
                    }
                }, up: { [weak self] p, tap in
                    guard let self else { return }
                    self.cancelTimer(hold)
                    if mode == "held" { return }
                    if mode == "gyms" {
                        rowDragging = false
                        let dx = p.x - point.x
                        rowTarget = max(0, min(Float(rooms.count - 1), (rowPosition + (dx < -40 ? 0.35 : dx > 40 ? -0.35 : 0)).rounded()))
                        return
                    }
                    if mode == "back" {
                        if k < 0.65 { deactivate(k) } else {
                            let k0 = k
                            self.anim(0.25) { u in k = k0 + (1 - k0) * Float(Ease.outCubic(u)); applyK() }
                        }
                        return
                    }
                    guard tap else { return }
                    switch keys[a] {
                    case "train":
                        guard self.touches(p, board.entity) else { return }
                        if boardHasPlan { trainStart() } else { upload() }
                    case "prs":
                        if self.touches(p, pen) {
                            self.buzz(.light)
                            self.checkSound()
                            self.menuActive = "prs"
                            self.prReturn = .menu
                            self.editOne = true
                            busy = true
                            self.panTo(.prDial)
                        } else if self.touches(p, book) {
                            prUpload()
                        }
                    default:
                        if Int(rowTarget.rounded()) >= gyms.count {
                            if let add = rooms.last, self.touches(p, add.entity) { newGym() }
                            return
                        }
                        if let flag = room.items["flag"], self.touches(p, flag) { edit(.name) }
                        else if let bars = room.items["bars"], self.touches(p, bars) { edit(.bar) }
                        else if let plates = room.items["plates"], self.touches(p, plates) { edit(.plates) }
                        else if let bell = room.items["bell"], self.touches(p, bell) { edit(.unit) }
                    }
                })
            }
            var x0 = point.x, t0 = self.t
            dragging = true
            return FlowDrag(move: { [weak self] p in
                guard let self else { return }
                let d = -Float((p.x - x0) / self.layoutScale) / pointsPerItem, now = self.t
                position += d
                velocity = d / Float(max(0.008, now - t0))
                x0 = p.x; t0 = now
            }, up: { [weak self] _, tap in
                guard let self else { return }
                dragging = false
                if self.t - t0 > 0.09 { velocity = 0 }
                if tap {
                    self.buzz(.light)
                    self.checkSound()
                    activate(index, false)
                }
            })
        }
    }
}
