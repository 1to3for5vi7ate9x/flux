use approx::{AbsDiffEq, RelativeEq};

#[derive(Debug, Clone, Copy)]
pub struct ScreenViewport {
    pub x: i32,
    pub y: i32,
    pub width: u32,
    pub height: u32,
}

impl ScreenViewport {
    pub fn new(x: i32, y: i32, width: u32, height: u32) -> Self {
        Self {
            x,
            y,
            width,
            height,
        }
    }

    pub fn translate(&mut self, dx: i32, dy: i32)  {
        self.x += dx;
        self.y += dy;
    }
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct ViewTransform {
    pub offset: [f32; 2],
    pub scale: [f32; 2],
}

impl Default for ViewTransform {
    fn default() -> Self {
        Self {
            offset: [0.0, 0.0],
            scale: [1.0, 1.0],
        }
    }
}

impl RelativeEq for ViewTransform {
    fn default_max_relative() -> Self::Epsilon {
        f32::EPSILON
    }

    fn relative_eq(
        &self,
        other: &Self,
        epsilon: Self::Epsilon,
        max_relative: Self::Epsilon,
    ) -> bool {
        self.offset
            .relative_eq(&other.offset, epsilon, max_relative)
            && self.scale.relative_eq(&other.scale, epsilon, max_relative)
    }
}

impl ViewTransform {
    pub fn from_screen_viewport(screen_size: &wgpu::Extent3d, viewport: &ScreenViewport) -> Self {
        let scene_width = screen_size.width as f32;
        let scene_height = screen_size.height as f32;

        let scale = [
            scene_width / viewport.width as f32,
            scene_height / viewport.height as f32,
        ];

        let offset = [
            2.0 * (scene_width - viewport.width as f32 + viewport.x as f32) / scene_width,
            -2.0 * (scene_height - viewport.height as f32 + viewport.y as f32) / scene_height,
        ];

        Self { offset, scale }
    }

    pub fn to_matrix(&self) -> glam::Mat4 {
        glam::Mat4::from_scale_rotation_translation(
            glam::Vec3::new(self.scale[0], self.scale[1], 1.0),
            glam::Quat::IDENTITY,
            glam::Vec3::new(self.offset[0], self.offset[1], 0.0),
        )
    }
}

impl AbsDiffEq for ViewTransform {
    type Epsilon = f32;

    fn default_epsilon() -> Self::Epsilon {
        f32::EPSILON
    }

    fn abs_diff_eq(&self, other: &Self, epsilon: Self::Epsilon) -> bool {
        self.offset.abs_diff_eq(&other.offset, epsilon)
            && self.scale.abs_diff_eq(&other.scale, epsilon)
    }
}

#[cfg(test)]
mod test {
    use super::*;
    use approx::assert_relative_eq;

    fn assert_view_transform(
        screen_size: wgpu::Extent3d,
        viewport: ScreenViewport,
        expected: ViewTransform,
    ) {
        let result = ViewTransform::from_screen_viewport(&screen_size, &viewport);
        assert_relative_eq!(
            result,
            expected,
            max_relative = f32::EPSILON,
            epsilon = f32::EPSILON,
        );
    }

    #[test]
    fn test_full_screen_viewport() {
        let screen_size = wgpu::Extent3d {
            width: 800,
            height: 600,
            ..Default::default()
        };
        assert_view_transform(
            screen_size,
            ScreenViewport::new(0, 0, 800, 600),
            ViewTransform {
                offset: [0.0, 0.0],
                scale: [1.0, 1.0],
            },
        );
    }

    #[test]
    fn test_half_screen_viewport() {
        let screen_size = wgpu::Extent3d {
            width: 800,
            height: 600,
            ..Default::default()
        };
        assert_view_transform(
            screen_size,
            ScreenViewport::new(0, 0, 400, 300),
            ViewTransform {
                offset: [1.0, -1.0],
                scale: [2.0, 2.0],
            },
        );
    }

    #[test]
    fn test_offset_viewport() {
        let screen_size = wgpu::Extent3d {
            width: 800,
            height: 600,
            ..Default::default()
        };
        assert_view_transform(
            screen_size,
            ScreenViewport::new(200, 150, 400, 300),
            ViewTransform {
                offset: [1.5, -1.5],
                scale: [2.0, 2.0],
            },
        );
    }

    #[test]
    fn test_wide_viewport() {
        let screen_size = wgpu::Extent3d {
            width: 800,
            height: 600,
            ..Default::default()
        };
        assert_view_transform(
            screen_size,
            ScreenViewport::new(0, 150, 800, 300),
            ViewTransform {
                offset: [0.0, -1.5],
                scale: [1.0, 2.0],
            },
        );
    }

    #[test]
    fn test_tall_viewport() {
        let screen_size = wgpu::Extent3d {
            width: 800,
            height: 600,
            ..Default::default()
        };
        assert_view_transform(
            screen_size,
            ScreenViewport::new(200, 0, 400, 600),
            ViewTransform {
                offset: [1.5, 0.0],
                scale: [2.0, 1.0],
            },
        );
    }

    #[test]
    fn test_small_viewport() {
        let screen_size = wgpu::Extent3d {
            width: 800,
            height: 600,
            ..Default::default()
        };
        assert_view_transform(
            screen_size,
            ScreenViewport::new(300, 200, 200, 200),
            ViewTransform {
                offset: [2.25, -2.0],
                scale: [4.0, 3.0],
            },
        );
    }
}
