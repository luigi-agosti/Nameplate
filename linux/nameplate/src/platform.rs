use cairo::{RectangleInt, Region};
use gtk::prelude::*;

#[derive(Clone, Copy)]
pub enum InputShape {
    Empty,
    Rectangle(RectangleInt),
}

pub fn prepare_window(
    window: &gtk::Window,
    _monitor: &gtk::gdk::Monitor,
    geometry: gtk::gdk::Rectangle,
    input: InputShape,
) {
    #[cfg(all(target_os = "linux", feature = "layer-shell"))]
    if is_wayland(&_monitor.display()) {
        use gtk4_layer_shell::{Edge, KeyboardMode, Layer, LayerShell};
        window.init_layer_shell();
        window.set_monitor(Some(_monitor));
        window.set_layer(Layer::Overlay);
        window.set_keyboard_mode(KeyboardMode::None);
        window.set_exclusive_zone(0);
        window.set_namespace(Some("nameplate"));
        for edge in [Edge::Left, Edge::Right, Edge::Top, Edge::Bottom] {
            window.set_anchor(edge, true);
        }
    }

    window.connect_realize(move |window| {
        let Some(surface) = window.surface() else {
            return;
        };
        let region = match input {
            InputShape::Empty => Region::create(),
            InputShape::Rectangle(rectangle) => Region::create_rectangle(&rectangle),
        };
        surface.set_input_region(Some(&region));
        configure_x11(&surface, geometry);
    });
}

#[cfg(all(target_os = "linux", feature = "layer-shell"))]
fn is_wayland(display: &gtk::gdk::Display) -> bool {
    display.type_().name().contains("Wayland")
}

#[cfg(target_os = "linux")]
fn configure_x11(surface: &gtk::gdk::Surface, geometry: gtk::gdk::Rectangle) {
    use gdk4_x11::{X11Display, X11Surface, x11::xlib};

    let Some(xsurface) = surface.downcast_ref::<X11Surface>() else {
        return;
    };
    let display = surface.display();
    let Some(xdisplay) = display.downcast_ref::<X11Display>() else {
        return;
    };
    let xid = xsurface.xid();
    let Ok(api) = xlib::Xlib::open() else {
        return;
    };
    // SAFETY: GDK owns this live X display; calls run on the GTK main thread.
    unsafe {
        let raw_display = xdisplay.xdisplay();
        let intern =
            |name: &[u8]| (api.XInternAtom)(raw_display, name.as_ptr().cast(), xlib::False);
        let net_wm_state = intern(b"_NET_WM_STATE\0");
        let states = [
            intern(b"_NET_WM_STATE_ABOVE\0"),
            intern(b"_NET_WM_STATE_SKIP_TASKBAR\0"),
            intern(b"_NET_WM_STATE_SKIP_PAGER\0"),
        ];
        (api.XChangeProperty)(
            raw_display,
            xid,
            net_wm_state,
            xlib::XA_ATOM,
            32,
            xlib::PropModeReplace,
            states.as_ptr().cast(),
            states.len() as i32,
        );
        let window_type = intern(b"_NET_WM_WINDOW_TYPE\0");
        let dock = intern(b"_NET_WM_WINDOW_TYPE_DOCK\0");
        (api.XChangeProperty)(
            raw_display,
            xid,
            window_type,
            xlib::XA_ATOM,
            32,
            xlib::PropModeReplace,
            (&dock as *const xlib::Atom).cast(),
            1,
        );
        (api.XMoveResizeWindow)(
            raw_display,
            xid,
            geometry.x(),
            geometry.y(),
            geometry.width() as u32,
            geometry.height() as u32,
        );
        (api.XRaiseWindow)(raw_display, xid);
        (api.XFlush)(raw_display);
    }
}

#[cfg(not(target_os = "linux"))]
fn configure_x11(_surface: &gtk::gdk::Surface, _geometry: gtk::gdk::Rectangle) {}
