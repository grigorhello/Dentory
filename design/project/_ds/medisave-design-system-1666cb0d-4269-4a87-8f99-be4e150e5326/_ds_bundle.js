/* @ds-bundle: {"format":4,"namespace":"MediSaveDesignSystem_1666cb","components":[{"name":"Button","sourcePath":"components/actions/Button.jsx"},{"name":"IconButton","sourcePath":"components/actions/IconButton.jsx"},{"name":"Badge","sourcePath":"components/display/Badge.jsx"},{"name":"Card","sourcePath":"components/display/Card.jsx"},{"name":"Icon","sourcePath":"components/display/Icon.jsx"},{"name":"Tabs","sourcePath":"components/display/Tabs.jsx"},{"name":"Tag","sourcePath":"components/display/Tag.jsx"},{"name":"Dialog","sourcePath":"components/feedback/Dialog.jsx"},{"name":"Toast","sourcePath":"components/feedback/Toast.jsx"},{"name":"Tooltip","sourcePath":"components/feedback/Tooltip.jsx"},{"name":"Checkbox","sourcePath":"components/forms/Checkbox.jsx"},{"name":"Input","sourcePath":"components/forms/Input.jsx"},{"name":"Radio","sourcePath":"components/forms/Radio.jsx"},{"name":"Select","sourcePath":"components/forms/Select.jsx"},{"name":"Switch","sourcePath":"components/forms/Switch.jsx"}],"sourceHashes":{"components/actions/Button.jsx":"40384dbf12c4","components/actions/IconButton.jsx":"cbd6f6523e20","components/display/Badge.jsx":"853ad204f2e7","components/display/Card.jsx":"f488bb591215","components/display/Icon.jsx":"5e6603749b19","components/display/Tabs.jsx":"35bffbff7eba","components/display/Tag.jsx":"2c4f1de1de4b","components/feedback/Dialog.jsx":"c50a822c92cb","components/feedback/Toast.jsx":"4fc5781adde5","components/feedback/Tooltip.jsx":"bd747252957d","components/forms/Checkbox.jsx":"336265ee1687","components/forms/Input.jsx":"f75b09cdd1dd","components/forms/Radio.jsx":"4caa7f267a83","components/forms/Select.jsx":"9616763b1b0d","components/forms/Switch.jsx":"fac4464e27bd","ui_kits/app/App.jsx":"c3f48b319821","ui_kits/app/Dashboard.jsx":"8d085e12fd28","ui_kits/app/Inventory.jsx":"20fff138dd52","ui_kits/app/InvoiceReview.jsx":"9b63f134776b","ui_kits/app/Procedure.jsx":"3914219c0348","ui_kits/app/ProductDetail.jsx":"515f4713eb96","ui_kits/app/Shell.jsx":"b9ea5f96fb92","ui_kits/app/data.js":"5a6fba3f183f"},"inlinedExternals":[],"unexposedExports":[]} */

(() => {

const __ds_ns = (window.MediSaveDesignSystem_1666cb = window.MediSaveDesignSystem_1666cb || {});

const __ds_scope = {};

(__ds_ns.__errors = __ds_ns.__errors || []);

// components/display/Badge.jsx
try { (() => {
const map = {
  neutral: ["var(--color-ink)", "var(--color-canvas-sunken)"],
  success: ["var(--color-success)", "var(--color-success-soft)"],
  warning: ["var(--color-warning)", "var(--color-warning-soft)"],
  danger: ["var(--color-danger)", "var(--color-danger-soft)"],
  info: ["var(--color-info)", "var(--color-info-soft)"]
};
const statusTone = {
  Healthy: "success",
  Low: "warning",
  "Out of stock": "danger",
  Expiring: "warning",
  Expired: "danger",
  "Missing expiry": "info",
  "Needs count": "info",
  Prepared: "info",
  Completed: "success",
  Cancelled: "neutral",
  Matched: "success",
  "Possible match": "warning",
  "New product": "info",
  "Needs review": "danger",
  Ordered: "info",
  Received: "success",
  "Needs order": "warning",
  Trial: "info",
  Active: "success",
  "Payment failed": "danger"
};
/** Status pill. Pass tone, or a known inventory status string as children to auto-tone. */
function Badge({
  tone,
  dot = false,
  size = "md",
  children,
  style
}) {
  const t = tone || statusTone[typeof children === "string" ? children : ""] || "neutral";
  const [fg, bg] = map[t];
  return /*#__PURE__*/React.createElement("span", {
    style: {
      display: "inline-flex",
      alignItems: "center",
      gap: 6,
      font: size === "sm" ? "var(--type-micro)" : "var(--type-caption-strong)",
      color: fg,
      background: bg,
      padding: size === "sm" ? "1px 8px" : "2px 10px",
      borderRadius: "var(--radius-pill)",
      whiteSpace: "nowrap",
      ...style
    }
  }, dot && /*#__PURE__*/React.createElement("i", {
    style: {
      width: 6,
      height: 6,
      borderRadius: "50%",
      background: fg
    }
  }), children);
}
Object.assign(__ds_scope, { Badge });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/display/Badge.jsx", error: String((e && e.message) || e) }); }

// components/display/Card.jsx
try { (() => {
/** Surface container. variant: soft (cream, default) | outline (ink hairline) | dark (flipped) | raised (canvas + shadow). */
function Card({
  variant = "soft",
  padding = 24,
  title,
  eyebrow,
  action,
  children,
  style,
  onClick
}) {
  const v = {
    soft: {
      background: "var(--surface-card)",
      color: "var(--color-ink)"
    },
    outline: {
      background: "var(--surface-page)",
      color: "var(--color-ink)",
      boxShadow: "var(--shadow-hairline)"
    },
    dark: {
      background: "var(--surface-dark)",
      color: "var(--text-on-dark)"
    },
    raised: {
      background: "var(--surface-raised)",
      color: "var(--color-ink)",
      boxShadow: "var(--shadow-md)"
    }
  }[variant];
  return /*#__PURE__*/React.createElement("section", {
    onClick: onClick,
    style: {
      borderRadius: "var(--radius-md)",
      padding,
      cursor: onClick ? "pointer" : undefined,
      ...v,
      ...style
    }
  }, (eyebrow || title || action) && /*#__PURE__*/React.createElement("header", {
    style: {
      display: "flex",
      alignItems: "flex-start",
      justifyContent: "space-between",
      gap: 12,
      marginBottom: children ? 16 : 0
    }
  }, /*#__PURE__*/React.createElement("div", null, eyebrow && /*#__PURE__*/React.createElement("div", {
    style: {
      font: "var(--type-eyebrow)",
      letterSpacing: 1,
      textTransform: "uppercase",
      color: variant === "dark" ? "var(--color-mute)" : "var(--text-secondary)",
      marginBottom: 6
    }
  }, eyebrow), title && /*#__PURE__*/React.createElement("h3", {
    style: {
      margin: 0,
      font: "var(--type-sub-sm)",
      letterSpacing: -0.6,
      color: "inherit"
    }
  }, title)), action), children);
}
Object.assign(__ds_scope, { Card });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/display/Card.jsx", error: String((e && e.message) || e) }); }

// components/display/Icon.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/** Lucide icon wrapper. Requires lucide UMD on window (https://unpkg.com/lucide@0.460.0/dist/umd/lucide.min.js). */
function Icon({
  name,
  size = 20,
  strokeWidth = 1.75,
  color = "currentColor",
  style,
  ...rest
}) {
  const ref = React.useRef(null);
  React.useEffect(() => {
    const el = ref.current;
    if (!el) return;
    el.innerHTML = "";
    const L = window.lucide;
    const node = L && L.icons && L.icons[name];
    if (!node) return;
    const svg = L.createElement(node, {
      width: size,
      height: size,
      "stroke-width": strokeWidth,
      stroke: color
    });
    el.appendChild(svg);
  }, [name, size, strokeWidth, color]);
  return /*#__PURE__*/React.createElement("span", _extends({
    ref: ref,
    "aria-hidden": "true",
    style: {
      display: "inline-flex",
      width: size,
      height: size,
      flex: "none",
      lineHeight: 0,
      ...style
    }
  }, rest));
}
Object.assign(__ds_scope, { Icon });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/display/Icon.jsx", error: String((e && e.message) || e) }); }

// components/actions/Button.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/** variant: primary (blue) | secondary (ink) | tertiary (outline) | text | danger. size: sm | md. */
function Button({
  variant = "primary",
  size = "md",
  icon,
  iconRight,
  loading = false,
  disabled = false,
  fullWidth = false,
  children,
  style,
  ...rest
}) {
  const [hover, setHover] = React.useState(false);
  const [press, setPress] = React.useState(false);
  const base = {
    primary: ["var(--color-primary)", "var(--color-on-primary)", "transparent", "var(--color-primary-hover)", "var(--color-primary-active)"],
    secondary: ["var(--color-ink)", "var(--color-on-primary)", "transparent", "var(--color-ink-soft)", "var(--color-ink-mid)"],
    tertiary: ["var(--surface-page)", "var(--color-ink)", "var(--color-ink)", "var(--surface-card)", "var(--color-canvas-sunken)"],
    text: ["transparent", "var(--color-ink)", "transparent", "var(--surface-card)", "var(--color-canvas-sunken)"],
    danger: ["var(--color-danger)", "var(--color-on-primary)", "transparent", "#b2322a", "#9a2b24"]
  }[variant];
  const bg = disabled ? variant === "text" || variant === "tertiary" ? "transparent" : "var(--color-mute)" : press ? base[4] : hover ? base[3] : base[0];
  const sm = size === "sm";
  return /*#__PURE__*/React.createElement("button", _extends({
    disabled: disabled || loading,
    onMouseEnter: () => setHover(true),
    onMouseLeave: () => {
      setHover(false);
      setPress(false);
    },
    onMouseDown: () => setPress(true),
    onMouseUp: () => setPress(false),
    style: {
      display: "inline-flex",
      alignItems: "center",
      justifyContent: "center",
      gap: 8,
      width: fullWidth ? "100%" : undefined,
      height: sm ? "var(--control-height-sm)" : "var(--control-height-lg)",
      padding: sm ? "0 16px" : "0 24px",
      font: sm ? "var(--type-button-sm)" : "var(--type-button-md)",
      letterSpacing: sm ? 0.144 : 0,
      color: disabled ? variant === "text" || variant === "tertiary" ? "var(--text-disabled)" : "var(--color-on-primary)" : base[1],
      background: bg,
      border: "1px solid " + (disabled && variant === "tertiary" ? "var(--color-mute)" : base[2]),
      borderRadius: "var(--radius-md)",
      cursor: disabled ? "not-allowed" : "pointer",
      transition: "background var(--duration-fast) var(--ease-standard)",
      whiteSpace: "nowrap",
      outline: "none",
      ...style
    },
    onFocus: e => e.currentTarget.style.boxShadow = "var(--focus-ring)",
    onBlur: e => e.currentTarget.style.boxShadow = "none"
  }, rest), loading ? /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "Loader2",
    size: sm ? 14 : 18,
    style: {
      animation: "msSpin 1s linear infinite"
    }
  }) : icon && /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: icon,
    size: sm ? 14 : 18
  }), children, iconRight && /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: iconRight,
    size: sm ? 14 : 18
  }), /*#__PURE__*/React.createElement("style", null, "@keyframes msSpin{to{transform:rotate(360deg)}}"));
}
Object.assign(__ds_scope, { Button });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/actions/Button.jsx", error: String((e && e.message) || e) }); }

// components/actions/IconButton.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/** Square icon-only button; always pass label (aria). variant: ghost | outline | solid. */
function IconButton({
  icon,
  label,
  variant = "ghost",
  size = "md",
  disabled = false,
  style,
  ...rest
}) {
  const [hover, setHover] = React.useState(false);
  const px = size === "sm" ? 32 : 40;
  const v = {
    ghost: {
      background: hover ? "var(--surface-card)" : "transparent",
      border: "1px solid transparent",
      color: "var(--color-ink)"
    },
    outline: {
      background: hover ? "var(--surface-card)" : "var(--surface-page)",
      border: "1px solid var(--color-ink)",
      color: "var(--color-ink)"
    },
    solid: {
      background: hover ? "var(--color-primary-hover)" : "var(--color-primary)",
      border: "1px solid transparent",
      color: "var(--color-on-primary)"
    }
  }[variant];
  return /*#__PURE__*/React.createElement("button", _extends({
    "aria-label": label,
    title: label,
    disabled: disabled,
    onMouseEnter: () => setHover(true),
    onMouseLeave: () => setHover(false),
    style: {
      display: "inline-grid",
      placeItems: "center",
      width: px,
      height: px,
      borderRadius: "var(--radius-sm)",
      cursor: disabled ? "not-allowed" : "pointer",
      opacity: disabled ? .4 : 1,
      padding: 0,
      transition: "background var(--duration-fast)",
      ...v,
      ...style
    }
  }, rest), /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: icon,
    size: size === "sm" ? 16 : 20
  }));
}
Object.assign(__ds_scope, { IconButton });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/actions/IconButton.jsx", error: String((e && e.message) || e) }); }

// components/display/Tabs.jsx
try { (() => {
/** Underline tabs. items: [{id,label,count?}] */
function Tabs({
  items,
  value,
  onChange,
  style
}) {
  return /*#__PURE__*/React.createElement("div", {
    role: "tablist",
    style: {
      display: "flex",
      gap: 4,
      borderBottom: "1px solid var(--color-line)",
      ...style
    }
  }, items.map(it => {
    const on = it.id === value;
    return /*#__PURE__*/React.createElement("button", {
      key: it.id,
      role: "tab",
      "aria-selected": on,
      onClick: () => onChange && onChange(it.id),
      style: {
        all: "unset",
        cursor: "pointer",
        padding: "10px 12px",
        marginBottom: -1,
        font: on ? "var(--type-body-sm-strong)" : "var(--type-body-sm)",
        color: on ? "var(--color-ink)" : "var(--text-body)",
        borderBottom: "2px solid " + (on ? "var(--color-primary)" : "transparent"),
        display: "inline-flex",
        gap: 8,
        alignItems: "center"
      }
    }, it.label, it.count != null && /*#__PURE__*/React.createElement("span", {
      style: {
        font: "var(--type-micro)",
        background: on ? "var(--color-primary-soft)" : "var(--color-canvas-sunken)",
        color: on ? "var(--color-primary)" : "var(--text-secondary)",
        padding: "1px 7px",
        borderRadius: "var(--radius-pill)"
      }
    }, it.count));
  }));
}
Object.assign(__ds_scope, { Tabs });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/display/Tabs.jsx", error: String((e && e.message) || e) }); }

// components/display/Tag.jsx
try { (() => {
/** Removable metadata chip (categories, suppliers, filters). */
function Tag({
  children,
  onRemove,
  selected = false,
  onClick,
  style
}) {
  return /*#__PURE__*/React.createElement("span", {
    onClick: onClick,
    style: {
      display: "inline-flex",
      alignItems: "center",
      gap: 6,
      font: "var(--type-caption)",
      color: selected ? "var(--color-on-primary)" : "var(--color-ink)",
      background: selected ? "var(--color-ink)" : "var(--surface-card)",
      border: "1px solid " + (selected ? "var(--color-ink)" : "var(--color-line)"),
      padding: "3px 10px",
      borderRadius: "var(--radius-pill)",
      cursor: onClick ? "pointer" : "default",
      ...style
    }
  }, children, onRemove && /*#__PURE__*/React.createElement("button", {
    onClick: e => {
      e.stopPropagation();
      onRemove();
    },
    "aria-label": "Remove",
    style: {
      all: "unset",
      cursor: "pointer",
      display: "inline-flex"
    }
  }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "X",
    size: 12
  })));
}
Object.assign(__ds_scope, { Tag });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/display/Tag.jsx", error: String((e && e.message) || e) }); }

// components/feedback/Dialog.jsx
try { (() => {
/** Modal dialog. Controlled by open; footer receives action buttons. */
function Dialog({
  open,
  onClose,
  title,
  description,
  children,
  footer,
  width = 480,
  inline = false
}) {
  if (!open) return null;
  const panel = /*#__PURE__*/React.createElement("div", {
    role: "dialog",
    "aria-modal": "true",
    style: {
      width,
      maxWidth: "100%",
      background: "var(--surface-raised)",
      borderRadius: "var(--radius-md)",
      boxShadow: "var(--shadow-lg)",
      padding: 24,
      display: "grid",
      gap: 16,
      color: "var(--color-ink)"
    }
  }, /*#__PURE__*/React.createElement("header", {
    style: {
      display: "flex",
      alignItems: "flex-start",
      gap: 12
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1
    }
  }, /*#__PURE__*/React.createElement("h2", {
    style: {
      margin: 0,
      font: "var(--type-sub-sm)",
      letterSpacing: -0.6
    }
  }, title), description && /*#__PURE__*/React.createElement("p", {
    style: {
      margin: "6px 0 0",
      font: "var(--type-body-sm)",
      color: "var(--text-body)"
    }
  }, description)), onClose && /*#__PURE__*/React.createElement(__ds_scope.IconButton, {
    icon: "X",
    label: "Close",
    size: "sm",
    onClick: onClose
  })), children, footer && /*#__PURE__*/React.createElement("footer", {
    style: {
      display: "flex",
      justifyContent: "flex-end",
      gap: 8
    }
  }, footer));
  if (inline) return panel;
  return /*#__PURE__*/React.createElement("div", {
    onClick: onClose,
    style: {
      position: "fixed",
      inset: 0,
      background: "rgba(32,21,21,.4)",
      display: "grid",
      placeItems: "center",
      padding: 16,
      zIndex: 50
    }
  }, /*#__PURE__*/React.createElement("div", {
    onClick: e => e.stopPropagation()
  }, panel));
}
Object.assign(__ds_scope, { Dialog });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/feedback/Dialog.jsx", error: String((e && e.message) || e) }); }

// components/feedback/Toast.jsx
try { (() => {
/** Transient notification. tone: neutral | success | warning | danger. */
function Toast({
  tone = "neutral",
  title,
  description,
  action,
  onDismiss,
  style
}) {
  const ic = {
    neutral: ["Info", "var(--color-ink)"],
    success: ["CheckCircle2", "var(--color-success)"],
    warning: ["AlertTriangle", "var(--color-warning)"],
    danger: ["XCircle", "var(--color-danger)"]
  }[tone];
  return /*#__PURE__*/React.createElement("div", {
    role: "status",
    style: {
      display: "flex",
      gap: 12,
      alignItems: "flex-start",
      width: 380,
      maxWidth: "100%",
      background: "var(--surface-raised)",
      borderRadius: "var(--radius-md)",
      boxShadow: "var(--shadow-md)",
      padding: "12px 16px",
      color: "var(--color-ink)",
      ...style
    }
  }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: ic[0],
    color: ic[1],
    style: {
      marginTop: 2
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      display: "grid",
      gap: 2
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      font: "var(--type-body-sm-strong)"
    }
  }, title), description && /*#__PURE__*/React.createElement("div", {
    style: {
      font: "var(--type-caption)",
      color: "var(--text-body)"
    }
  }, description), action && /*#__PURE__*/React.createElement("div", {
    style: {
      marginTop: 6
    }
  }, action)), onDismiss && /*#__PURE__*/React.createElement("button", {
    onClick: onDismiss,
    "aria-label": "Dismiss",
    style: {
      all: "unset",
      cursor: "pointer",
      color: "var(--text-secondary)",
      display: "inline-flex"
    }
  }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "X",
    size: 16
  })));
}
Object.assign(__ds_scope, { Toast });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/feedback/Toast.jsx", error: String((e && e.message) || e) }); }

// components/feedback/Tooltip.jsx
try { (() => {
/** Hover tooltip; wraps children. */
function Tooltip({
  content,
  children,
  side = "top"
}) {
  const [on, setOn] = React.useState(false);
  const pos = {
    top: {
      bottom: "calc(100% + 6px)",
      left: "50%",
      transform: "translateX(-50%)"
    },
    bottom: {
      top: "calc(100% + 6px)",
      left: "50%",
      transform: "translateX(-50%)"
    },
    right: {
      left: "calc(100% + 6px)",
      top: "50%",
      transform: "translateY(-50%)"
    },
    left: {
      right: "calc(100% + 6px)",
      top: "50%",
      transform: "translateY(-50%)"
    }
  }[side];
  return /*#__PURE__*/React.createElement("span", {
    style: {
      position: "relative",
      display: "inline-flex"
    },
    onMouseEnter: () => setOn(true),
    onMouseLeave: () => setOn(false)
  }, children, on && /*#__PURE__*/React.createElement("span", {
    role: "tooltip",
    style: {
      position: "absolute",
      ...pos,
      background: "var(--color-ink)",
      color: "var(--text-on-dark)",
      font: "var(--type-caption)",
      padding: "6px 10px",
      borderRadius: "var(--radius-sm)",
      whiteSpace: "nowrap",
      zIndex: 40,
      pointerEvents: "none"
    }
  }, content));
}
Object.assign(__ds_scope, { Tooltip });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/feedback/Tooltip.jsx", error: String((e && e.message) || e) }); }

// components/forms/Checkbox.jsx
try { (() => {
const box = (on, shape) => ({
  width: 18,
  height: 18,
  borderRadius: shape === "radio" ? "50%" : 4,
  border: "1px solid " + (on ? "var(--color-primary)" : "var(--color-ink)"),
  background: on ? "var(--color-primary)" : "var(--surface-page)",
  display: "inline-grid",
  placeItems: "center",
  flex: "none",
  transition: "background var(--duration-fast)"
});
function Checkbox({
  checked = false,
  onChange,
  label,
  description,
  disabled = false,
  style
}) {
  return /*#__PURE__*/React.createElement("label", {
    style: {
      display: "flex",
      gap: 10,
      alignItems: "flex-start",
      cursor: disabled ? "not-allowed" : "pointer",
      opacity: disabled ? .5 : 1,
      ...style
    }
  }, /*#__PURE__*/React.createElement("input", {
    type: "checkbox",
    checked: checked,
    disabled: disabled,
    onChange: e => onChange && onChange(e.target.checked),
    style: {
      position: "absolute",
      opacity: 0,
      width: 0,
      height: 0
    }
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      ...box(checked),
      marginTop: 2
    }
  }, checked && /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "Check",
    size: 13,
    strokeWidth: 3,
    color: "var(--color-on-primary)"
  })), (label || description) && /*#__PURE__*/React.createElement("span", {
    style: {
      display: "grid",
      gap: 2
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      font: "var(--type-body-sm)",
      color: "var(--color-ink)"
    }
  }, label), description && /*#__PURE__*/React.createElement("span", {
    style: {
      font: "var(--type-caption)",
      color: "var(--text-secondary)"
    }
  }, description)));
}
Object.assign(__ds_scope, { Checkbox });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/forms/Checkbox.jsx", error: String((e && e.message) || e) }); }

// components/forms/Input.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
function Field({
  label,
  hint,
  error,
  required,
  children
}) {
  return /*#__PURE__*/React.createElement("label", {
    style: {
      display: "grid",
      gap: 6
    }
  }, label && /*#__PURE__*/React.createElement("span", {
    style: {
      font: "var(--type-caption-strong)",
      color: "var(--color-ink)"
    }
  }, label, required && /*#__PURE__*/React.createElement("span", {
    style: {
      color: "var(--color-danger)"
    }
  }, " *")), children, (error || hint) && /*#__PURE__*/React.createElement("span", {
    style: {
      font: "var(--type-caption)",
      color: error ? "var(--color-danger)" : "var(--text-secondary)"
    }
  }, error || hint));
}
/** Text input, 6px radius, ink hairline; prefix/suffix adornments. */
function Input({
  label,
  hint,
  error,
  required,
  icon,
  suffix,
  size = "md",
  style,
  inputStyle,
  ...rest
}) {
  const [focus, setFocus] = React.useState(false);
  return /*#__PURE__*/React.createElement(Field, {
    label: label,
    hint: hint,
    error: error,
    required: required
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      display: "flex",
      alignItems: "center",
      gap: 8,
      height: size === "sm" ? "var(--control-height-sm)" : "var(--control-height-md)",
      padding: "0 12px",
      background: rest.disabled ? "var(--surface-card)" : "var(--surface-page)",
      border: "1px solid " + (error ? "var(--color-danger)" : focus ? "var(--color-primary)" : "var(--color-ink)"),
      borderRadius: "var(--radius-sm)",
      boxShadow: focus ? "var(--focus-ring)" : "none",
      transition: "box-shadow var(--duration-fast)",
      ...style
    }
  }, icon && /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: icon,
    size: 16,
    color: "var(--text-secondary)"
  }), /*#__PURE__*/React.createElement("input", _extends({
    onFocus: () => setFocus(true),
    onBlur: () => setFocus(false),
    style: {
      all: "unset",
      flex: 1,
      minWidth: 0,
      font: size === "sm" ? "var(--type-caption)" : "var(--type-body-sm)",
      color: "var(--color-ink)",
      ...inputStyle
    }
  }, rest)), suffix && /*#__PURE__*/React.createElement("span", {
    style: {
      font: "var(--type-caption)",
      color: "var(--text-secondary)"
    }
  }, suffix)));
}
Object.assign(__ds_scope, { Input });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/forms/Input.jsx", error: String((e && e.message) || e) }); }

// components/forms/Radio.jsx
try { (() => {
const box = (on, shape) => ({
  width: 18,
  height: 18,
  borderRadius: shape === "radio" ? "50%" : 4,
  border: "1px solid " + (on ? "var(--color-primary)" : "var(--color-ink)"),
  background: on ? "var(--color-primary)" : "var(--surface-page)",
  display: "inline-grid",
  placeItems: "center",
  flex: "none",
  transition: "background var(--duration-fast)"
});
/** Radio group. options: [{value,label,description?}] */
function Radio({
  name,
  options = [],
  value,
  onChange,
  inline = false,
  style
}) {
  return /*#__PURE__*/React.createElement("div", {
    role: "radiogroup",
    style: {
      display: "flex",
      flexDirection: inline ? "row" : "column",
      gap: inline ? 20 : 10,
      ...style
    }
  }, options.map(o => {
    const on = o.value === value;
    return /*#__PURE__*/React.createElement("label", {
      key: o.value,
      style: {
        display: "flex",
        gap: 10,
        alignItems: "flex-start",
        cursor: "pointer"
      }
    }, /*#__PURE__*/React.createElement("input", {
      type: "radio",
      name: name,
      checked: on,
      onChange: () => onChange && onChange(o.value),
      style: {
        position: "absolute",
        opacity: 0,
        width: 0,
        height: 0
      }
    }), /*#__PURE__*/React.createElement("span", {
      style: {
        ...box(on, "radio"),
        marginTop: 2
      }
    }, on && /*#__PURE__*/React.createElement("i", {
      style: {
        width: 7,
        height: 7,
        borderRadius: "50%",
        background: "var(--color-on-primary)"
      }
    })), /*#__PURE__*/React.createElement("span", {
      style: {
        display: "grid",
        gap: 2
      }
    }, /*#__PURE__*/React.createElement("span", {
      style: {
        font: "var(--type-body-sm)",
        color: "var(--color-ink)"
      }
    }, o.label), o.description && /*#__PURE__*/React.createElement("span", {
      style: {
        font: "var(--type-caption)",
        color: "var(--text-secondary)"
      }
    }, o.description)));
  }));
}
Object.assign(__ds_scope, { Radio });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/forms/Radio.jsx", error: String((e && e.message) || e) }); }

// components/forms/Select.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
function Field({
  label,
  hint,
  error,
  required,
  children
}) {
  return /*#__PURE__*/React.createElement("label", {
    style: {
      display: "grid",
      gap: 6
    }
  }, label && /*#__PURE__*/React.createElement("span", {
    style: {
      font: "var(--type-caption-strong)",
      color: "var(--color-ink)"
    }
  }, label, required && /*#__PURE__*/React.createElement("span", {
    style: {
      color: "var(--color-danger)"
    }
  }, " *")), children, (error || hint) && /*#__PURE__*/React.createElement("span", {
    style: {
      font: "var(--type-caption)",
      color: error ? "var(--color-danger)" : "var(--text-secondary)"
    }
  }, error || hint));
}
/** Native select styled to match Input. options: string[] | {value,label}[] */
function Select({
  label,
  hint,
  error,
  required,
  options = [],
  placeholder,
  size = "md",
  style,
  ...rest
}) {
  return /*#__PURE__*/React.createElement(Field, {
    label: label,
    hint: hint,
    error: error,
    required: required
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      position: "relative",
      display: "flex"
    }
  }, /*#__PURE__*/React.createElement("select", _extends({
    style: {
      appearance: "none",
      WebkitAppearance: "none",
      width: "100%",
      height: size === "sm" ? "var(--control-height-sm)" : "var(--control-height-md)",
      padding: "0 36px 0 12px",
      font: size === "sm" ? "var(--type-caption)" : "var(--type-body-sm)",
      color: "var(--color-ink)",
      background: "var(--surface-page)",
      border: "1px solid " + (error ? "var(--color-danger)" : "var(--color-ink)"),
      borderRadius: "var(--radius-sm)",
      outline: "none",
      ...style
    }
  }, rest), placeholder && /*#__PURE__*/React.createElement("option", {
    value: ""
  }, placeholder), options.map(o => typeof o === "string" ? /*#__PURE__*/React.createElement("option", {
    key: o,
    value: o
  }, o) : /*#__PURE__*/React.createElement("option", {
    key: o.value,
    value: o.value
  }, o.label))), /*#__PURE__*/React.createElement("span", {
    style: {
      position: "absolute",
      right: 10,
      top: "50%",
      transform: "translateY(-50%)",
      pointerEvents: "none",
      color: "var(--text-secondary)"
    }
  }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "ChevronDown",
    size: 16
  }))));
}
Object.assign(__ds_scope, { Select });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/forms/Select.jsx", error: String((e && e.message) || e) }); }

// components/forms/Switch.jsx
try { (() => {
function Switch({
  checked = false,
  onChange,
  label,
  disabled = false,
  style
}) {
  return /*#__PURE__*/React.createElement("label", {
    style: {
      display: "inline-flex",
      alignItems: "center",
      gap: 10,
      cursor: disabled ? "not-allowed" : "pointer",
      opacity: disabled ? .5 : 1,
      ...style
    }
  }, /*#__PURE__*/React.createElement("input", {
    type: "checkbox",
    role: "switch",
    checked: checked,
    disabled: disabled,
    onChange: e => onChange && onChange(e.target.checked),
    style: {
      position: "absolute",
      opacity: 0,
      width: 0,
      height: 0
    }
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      width: 40,
      height: 24,
      borderRadius: "var(--radius-pill)",
      background: checked ? "var(--color-primary)" : "var(--color-mute)",
      position: "relative",
      transition: "background var(--duration-base) var(--ease-standard)",
      flex: "none"
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      position: "absolute",
      top: 3,
      left: checked ? 19 : 3,
      width: 18,
      height: 18,
      borderRadius: "50%",
      background: "var(--color-canvas)",
      transition: "left var(--duration-base) var(--ease-standard)",
      boxShadow: "var(--shadow-soft)"
    }
  })), label && /*#__PURE__*/React.createElement("span", {
    style: {
      font: "var(--type-body-sm)",
      color: "var(--color-ink)"
    }
  }, label));
}
Object.assign(__ds_scope, { Switch });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/forms/Switch.jsx", error: String((e && e.message) || e) }); }

// ui_kits/app/App.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
const {
  Toast,
  Button,
  Card
} = window.MediSaveDesignSystem_1666cb;
function Placeholder({
  title
}) {
  return /*#__PURE__*/React.createElement(Card, {
    padding: 48,
    style: {
      textAlign: "center"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      font: "var(--type-body-md)",
      color: "var(--text-secondary)"
    }
  }, title, " \u2013 not detailed in the PRD beyond the list; left intentionally blank."));
}
function App() {
  const [screen, setScreen] = React.useState("dash");
  const [product, setProduct] = React.useState(window.MS.products[0]);
  const [toasts, setToasts] = React.useState([]);
  const go = (s, p) => {
    if (p) setProduct(p);
    setScreen(s);
    window.scrollTo(0, 0);
  };
  const toast = t => {
    const id = Date.now();
    setToasts(x => [...x, {
      ...t,
      id
    }]);
    setTimeout(() => setToasts(x => x.filter(y => y.id !== id)), 5000);
  };
  const titles = {
    dash: "Dashboard",
    inv: "Inventory",
    product: product.name,
    receive: "Receive delivery",
    invoice: "Review invoice",
    proc: "Procedures",
    order: "Need to order",
    count: "Quick count",
    log: "Activity",
    settings: "Settings"
  };
  const crumbs = {
    product: "Inventory",
    invoice: "Receive delivery"
  }[screen];
  const actions = screen === "inv" ? /*#__PURE__*/React.createElement(Button, {
    size: "sm",
    icon: "Truck",
    onClick: () => go("receive")
  }, "Receive delivery") : screen === "dash" ? /*#__PURE__*/React.createElement(Button, {
    size: "sm",
    icon: "ClipboardCheck",
    onClick: () => go("proc")
  }, "Start procedure") : null;
  return /*#__PURE__*/React.createElement(Shell, {
    screen: screen,
    setScreen: go,
    title: titles[screen],
    crumbs: crumbs,
    actions: actions
  }, screen === "dash" && /*#__PURE__*/React.createElement(Dashboard, {
    go: go
  }), screen === "inv" && /*#__PURE__*/React.createElement(Inventory, {
    go: go
  }), screen === "product" && /*#__PURE__*/React.createElement(ProductDetail, {
    p: product,
    go: go,
    toast: toast
  }), screen === "invoice" && /*#__PURE__*/React.createElement(InvoiceReview, {
    go: go,
    toast: toast
  }), screen === "receive" && /*#__PURE__*/React.createElement(ManualReceive, {
    go: go,
    toast: toast
  }), screen === "proc" && /*#__PURE__*/React.createElement(Procedure, {
    toast: toast
  }), ["order", "count", "log", "settings"].includes(screen) && /*#__PURE__*/React.createElement(Placeholder, {
    title: titles[screen]
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      position: "fixed",
      right: 24,
      bottom: 24,
      display: "grid",
      gap: 8,
      zIndex: 60
    }
  }, toasts.map(t => /*#__PURE__*/React.createElement(Toast, _extends({
    key: t.id
  }, t, {
    onDismiss: () => setToasts(x => x.filter(y => y.id !== t.id))
  })))));
}
ReactDOM.createRoot(document.getElementById("root")).render(/*#__PURE__*/React.createElement(App, null));
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/app/App.jsx", error: String((e && e.message) || e) }); }

// ui_kits/app/Dashboard.jsx
try { (() => {
const {
  Card,
  Badge,
  Button,
  Icon
} = window.MediSaveDesignSystem_1666cb;
function Stat({
  label,
  value,
  sub
}) {
  return /*#__PURE__*/React.createElement(Card, {
    padding: 20
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      font: "var(--type-caption)",
      color: "var(--text-secondary)"
    }
  }, label), /*#__PURE__*/React.createElement("div", {
    style: {
      font: "var(--type-display-md)",
      letterSpacing: 1,
      marginTop: 6
    }
  }, value), sub && /*#__PURE__*/React.createElement("div", {
    style: {
      font: "var(--type-caption)",
      color: "var(--text-body)",
      marginTop: 4
    }
  }, sub));
}
function Dashboard({
  go
}) {
  const P = window.MS.products;
  const attention = [["Low stock", P.filter(p => p.status === "Low" || p.status === "Out of stock").length, "warning", "inv"], ["Expiring soon", P.filter(p => p.status === "Expiring").length + 1, "danger", "inv"], ["Missing expiry information", 1, "info", "inv"], ["Items need counting", 4, "info", "count"]];
  return /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement("div", {
    style: {
      font: "var(--type-eyebrow)",
      letterSpacing: 1,
      textTransform: "uppercase",
      color: "var(--text-secondary)"
    }
  }, "Thursday, October 2"), /*#__PURE__*/React.createElement("h2", {
    style: {
      font: "var(--type-display-lg)",
      marginTop: 8
    }
  }, "Good morning, Sarah")), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "grid",
      gridTemplateColumns: "1.3fr 1fr",
      gap: 24,
      alignItems: "start"
    }
  }, /*#__PURE__*/React.createElement(Card, {
    eyebrow: "Needs attention",
    title: "4 things to look at",
    action: /*#__PURE__*/React.createElement(Button, {
      variant: "text",
      size: "sm",
      iconRight: "ArrowRight",
      onClick: () => go("inv")
    }, "Inventory")
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "grid",
      gap: 2
    }
  }, attention.map(([l, n, t, s]) => /*#__PURE__*/React.createElement("button", {
    key: l,
    onClick: () => go(s),
    style: {
      all: "unset",
      cursor: "pointer",
      display: "flex",
      alignItems: "center",
      gap: 14,
      padding: "12px 12px",
      margin: "0 -12px",
      borderRadius: "var(--radius-sm)",
      borderBottom: "1px solid var(--color-line)"
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      font: "var(--type-display-xs)",
      letterSpacing: -0.5,
      color: "var(--color-" + t + ")",
      minWidth: 28
    }
  }, n), /*#__PURE__*/React.createElement("span", {
    style: {
      font: "var(--type-body-sm)",
      color: "var(--color-ink)",
      flex: 1
    }
  }, l), /*#__PURE__*/React.createElement(Icon, {
    name: "ChevronRight",
    size: 16,
    color: "var(--text-secondary)"
  }))))), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "grid",
      gap: 16
    }
  }, /*#__PURE__*/React.createElement(Card, {
    variant: "dark",
    padding: 24
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      font: "var(--type-eyebrow)",
      letterSpacing: 1,
      textTransform: "uppercase",
      color: "var(--color-mute)"
    }
  }, "Receive delivery"), /*#__PURE__*/React.createElement("div", {
    style: {
      font: "var(--type-body-md)",
      margin: "10px 0 16px",
      color: "var(--text-on-dark)"
    }
  }, "Upload an invoice or photo. AI reads the lines, you confirm."), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      gap: 8
    }
  }, /*#__PURE__*/React.createElement(Button, {
    icon: "Upload",
    onClick: () => go("invoice")
  }, "Upload invoice"), /*#__PURE__*/React.createElement(Button, {
    variant: "text",
    style: {
      color: "var(--text-on-dark)"
    },
    onClick: () => go("receive")
  }, "Receive manually"))), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "grid",
      gridTemplateColumns: "1fr 1fr",
      gap: 16
    }
  }, /*#__PURE__*/React.createElement(Stat, {
    label: "Inventory value",
    value: "$12,420"
  }), /*#__PURE__*/React.createElement(Stat, {
    label: "Expiring within 90 days",
    value: "$186",
    sub: "34 cartridges + 1 bottle"
  })))), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "grid",
      gridTemplateColumns: "1fr 1fr 1fr",
      gap: 16
    }
  }, /*#__PURE__*/React.createElement(Card, {
    eyebrow: "Need to order",
    title: "6 products",
    action: /*#__PURE__*/React.createElement(Button, {
      variant: "text",
      size: "sm",
      onClick: () => go("order")
    }, "Open list")
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      font: "var(--type-caption)",
      color: "var(--text-body)"
    }
  }, "3 products already ordered from Patterson, Oct 1.")), /*#__PURE__*/React.createElement(Card, {
    eyebrow: "Expiring soon",
    title: "Bonding agent",
    action: /*#__PURE__*/React.createElement(Badge, null, "Expiring")
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      font: "var(--type-caption)",
      color: "var(--text-body)"
    }
  }, "1 bottle \xB7 32 days \xB7 $82. Use or dispose before waste.")), /*#__PURE__*/React.createElement(Card, {
    eyebrow: "Onboarding",
    title: "4 of 6 done"
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "grid",
      gap: 6,
      font: "var(--type-caption)"
    }
  }, [["Create clinic", 1], ["Add first 10 products", 1], ["Configure one procedure", 1], ["Receive first invoice", 1], ["Invite teammate", 0], ["Complete first procedure", 0]].map(([t, d]) => /*#__PURE__*/React.createElement("div", {
    key: t,
    style: {
      display: "flex",
      gap: 8,
      alignItems: "center",
      color: d ? "var(--text-secondary)" : "var(--color-ink)"
    }
  }, /*#__PURE__*/React.createElement(Icon, {
    name: d ? "CheckCircle2" : "Circle",
    size: 14,
    color: d ? "var(--color-success)" : "var(--color-mute)"
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      textDecoration: d ? "line-through" : "none"
    }
  }, t)))))));
}
window.Dashboard = Dashboard;
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/app/Dashboard.jsx", error: String((e && e.message) || e) }); }

// ui_kits/app/Inventory.jsx
try { (() => {
const {
  Card,
  Badge,
  Button,
  Tabs,
  Tag,
  Select,
  Tooltip,
  IconButton
} = window.MediSaveDesignSystem_1666cb;
const th = {
  textAlign: "left",
  padding: "12px 16px",
  font: "var(--type-caption-strong)",
  color: "var(--text-secondary)",
  background: "var(--surface-card)",
  borderBottom: "1px solid var(--color-line)",
  whiteSpace: "nowrap"
};
const td = {
  padding: "12px 16px",
  font: "var(--type-body-sm)",
  color: "var(--color-ink)",
  borderBottom: "1px solid var(--color-line)",
  verticalAlign: "middle"
};
function Inventory({
  go
}) {
  const P = window.MS.products;
  const [tab, setTab] = React.useState("all");
  const [cat, setCat] = React.useState(null);
  const filt = {
    all: () => true,
    low: p => p.status === "Low" || p.status === "Out of stock",
    exp: p => p.status === "Expiring" || p.status === "Missing expiry",
    count: p => p.status === "Needs count"
  }[tab];
  const rows = P.filter(filt).filter(p => !cat || p.cat === cat);
  const cats = [...new Set(P.map(p => p.cat))];
  return /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement(Tabs, {
    items: [{
      id: "all",
      label: "All",
      count: P.length
    }, {
      id: "low",
      label: "Low / out",
      count: P.filter(p => p.status === "Low" || p.status === "Out of stock").length
    }, {
      id: "exp",
      label: "Expiry",
      count: 2
    }, {
      id: "count",
      label: "Needs count",
      count: 1
    }],
    value: tab,
    onChange: setTab
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      gap: 8,
      alignItems: "center",
      flexWrap: "wrap"
    }
  }, cats.map(c => /*#__PURE__*/React.createElement(Tag, {
    key: c,
    selected: cat === c,
    onClick: () => setCat(cat === c ? null : c)
  }, c)), /*#__PURE__*/React.createElement("div", {
    style: {
      marginLeft: "auto",
      display: "flex",
      gap: 8,
      alignItems: "center"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: 160
    }
  }, /*#__PURE__*/React.createElement(Select, {
    size: "sm",
    options: ["Name", "Status", "Quantity", "Expiry"]
  })), /*#__PURE__*/React.createElement(Button, {
    size: "sm",
    icon: "Plus"
  }, "Add product"))), /*#__PURE__*/React.createElement("div", {
    style: {
      border: "1px solid var(--color-line)",
      borderRadius: "var(--radius-md)",
      overflow: "hidden"
    }
  }, /*#__PURE__*/React.createElement("table", {
    style: {
      width: "100%",
      borderCollapse: "collapse"
    }
  }, /*#__PURE__*/React.createElement("thead", null, /*#__PURE__*/React.createElement("tr", null, /*#__PURE__*/React.createElement("th", {
    style: th
  }, "Product"), /*#__PURE__*/React.createElement("th", {
    style: th
  }, "Category"), /*#__PURE__*/React.createElement("th", {
    style: th
  }, "Mode"), /*#__PURE__*/React.createElement("th", {
    style: {
      ...th,
      textAlign: "right"
    }
  }, "Usable"), /*#__PURE__*/React.createElement("th", {
    style: {
      ...th,
      textAlign: "right"
    }
  }, "Min / target"), /*#__PURE__*/React.createElement("th", {
    style: th
  }, "Next expiry"), /*#__PURE__*/React.createElement("th", {
    style: th
  }, "Status"), /*#__PURE__*/React.createElement("th", {
    style: th
  }))), /*#__PURE__*/React.createElement("tbody", null, rows.map(p => /*#__PURE__*/React.createElement("tr", {
    key: p.id,
    onClick: () => go("product", p),
    style: {
      cursor: "pointer"
    },
    onMouseEnter: e => e.currentTarget.style.background = "var(--surface-card)",
    onMouseLeave: e => e.currentTarget.style.background = "transparent"
  }, /*#__PURE__*/React.createElement("td", {
    style: {
      ...td,
      font: "var(--type-body-sm-strong)"
    }
  }, p.name), /*#__PURE__*/React.createElement("td", {
    style: {
      ...td,
      color: "var(--text-body)"
    }
  }, p.cat), /*#__PURE__*/React.createElement("td", {
    style: {
      ...td,
      color: "var(--text-body)"
    }
  }, p.mode), /*#__PURE__*/React.createElement("td", {
    style: {
      ...td,
      textAlign: "right"
    }
  }, p.status === "Needs count" ? /*#__PURE__*/React.createElement(Tooltip, {
    content: "Estimated since last count on Sep 12"
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      color: "var(--color-info)"
    }
  }, "~", p.avail - p.reserved)) : p.avail - p.reserved, " ", /*#__PURE__*/React.createElement("span", {
    style: {
      font: "var(--type-caption)",
      color: "var(--text-secondary)"
    }
  }, p.unit)), /*#__PURE__*/React.createElement("td", {
    style: {
      ...td,
      textAlign: "right",
      color: "var(--text-body)"
    }
  }, p.min, " / ", p.target), /*#__PURE__*/React.createElement("td", {
    style: {
      ...td,
      color: "var(--text-body)"
    }
  }, p.expiry), /*#__PURE__*/React.createElement("td", {
    style: td
  }, /*#__PURE__*/React.createElement(Badge, {
    dot: true
  }, p.status)), /*#__PURE__*/React.createElement("td", {
    style: {
      ...td,
      textAlign: "right"
    }
  }, /*#__PURE__*/React.createElement(IconButton, {
    icon: "MoreHorizontal",
    label: "Actions",
    size: "sm",
    onClick: e => e.stopPropagation()
  })))), rows.length === 0 && /*#__PURE__*/React.createElement("tr", null, /*#__PURE__*/React.createElement("td", {
    colSpan: 8,
    style: {
      padding: 48,
      textAlign: "center",
      font: "var(--type-body-md)",
      color: "var(--text-secondary)",
      background: "var(--surface-card)"
    }
  }, "No products match these filters."))))));
}
window.Inventory = Inventory;
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/app/Inventory.jsx", error: String((e && e.message) || e) }); }

// ui_kits/app/InvoiceReview.jsx
try { (() => {
const {
  Card,
  Badge,
  Button,
  Icon,
  Input,
  Select,
  Radio
} = window.MediSaveDesignSystem_1666cb;
function InvoiceReview({
  go,
  toast
}) {
  const I = window.MS.invoice;
  const [lines, setLines] = React.useState(I.lines);
  const set = (i, patch) => setLines(lines.map((l, j) => j === i ? {
    ...l,
    ...patch
  } : l));
  const ready = lines.every(l => l.state === "Matched" || l.state === "Skipped" || l.state === "Created");
  return /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "grid",
      gridTemplateColumns: "1fr 300px",
      gap: 24,
      alignItems: "start"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "grid",
      gap: 16
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      padding: "12px 16px",
      background: "var(--color-info-soft)",
      color: "var(--color-info)",
      borderRadius: "var(--radius-sm)",
      font: "var(--type-caption-strong)",
      display: "flex",
      gap: 8,
      alignItems: "center"
    }
  }, /*#__PURE__*/React.createElement(Icon, {
    name: "Sparkles",
    size: 16
  }), "AI read 4 lines from this invoice. Nothing affects inventory until you confirm."), lines.map((l, i) => /*#__PURE__*/React.createElement(Card, {
    key: i,
    variant: l.state === "Needs review" ? "outline" : "soft",
    padding: 20
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "grid",
      gridTemplateColumns: "minmax(0,1fr) auto",
      gap: 16
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "grid",
      gap: 10,
      minWidth: 0
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      gap: 10,
      alignItems: "center"
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      font: "var(--type-mono-sm)",
      color: "var(--text-body)"
    }
  }, l.desc), /*#__PURE__*/React.createElement(Badge, {
    size: "sm"
  }, l.state)), l.state === "Matched" && /*#__PURE__*/React.createElement("div", {
    style: {
      font: "var(--type-body-sm-strong)",
      display: "flex",
      gap: 8,
      alignItems: "center"
    }
  }, /*#__PURE__*/React.createElement(Icon, {
    name: "ArrowRight",
    size: 14,
    color: "var(--text-secondary)"
  }), l.match), l.state === "Possible match" && /*#__PURE__*/React.createElement("div", {
    style: {
      display: "grid",
      gap: 8
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      font: "var(--type-caption)",
      color: "var(--text-body)"
    }
  }, "System suggests ", /*#__PURE__*/React.createElement("b", {
    style: {
      color: "var(--color-ink)"
    }
  }, l.match)), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      gap: 8
    }
  }, /*#__PURE__*/React.createElement(Button, {
    size: "sm",
    onClick: () => set(i, {
      state: "Matched"
    })
  }, "Match existing product"), /*#__PURE__*/React.createElement(Button, {
    size: "sm",
    variant: "tertiary",
    onClick: () => set(i, {
      state: "Created",
      match: l.desc
    })
  }, "Create new product"))), l.state === "New product" && /*#__PURE__*/React.createElement("div", {
    style: {
      display: "grid",
      gap: 8
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "grid",
      gridTemplateColumns: "repeat(3,minmax(0,1fr))",
      gap: 8
    }
  }, /*#__PURE__*/React.createElement(Input, {
    size: "sm",
    label: "Product name",
    defaultValue: "Temp-Bond NE"
  }), /*#__PURE__*/React.createElement(Select, {
    size: "sm",
    label: "Category",
    options: ["Cement", "Restorative", "Disposable"]
  }), /*#__PURE__*/React.createElement(Select, {
    size: "sm",
    label: "Tracking",
    options: ["Unit tracked", "Package tracked", "Container / bulk"]
  })), /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement(Button, {
    size: "sm",
    variant: "secondary",
    onClick: () => set(i, {
      state: "Created",
      match: "Temp-Bond NE"
    })
  }, "Create product"))), l.state === "Needs review" && /*#__PURE__*/React.createElement("div", {
    style: {
      display: "grid",
      gap: 8
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      font: "var(--type-caption)",
      color: "var(--text-body)"
    }
  }, "Not a product line. Skip it or match manually."), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      gap: 8
    }
  }, /*#__PURE__*/React.createElement(Button, {
    size: "sm",
    variant: "tertiary",
    onClick: () => set(i, {
      state: "Skipped"
    })
  }, "Skip line"), /*#__PURE__*/React.createElement(Button, {
    size: "sm",
    variant: "text"
  }, "Match manually"))), l.state === "Created" && /*#__PURE__*/React.createElement("div", {
    style: {
      font: "var(--type-body-sm-strong)",
      display: "flex",
      gap: 8,
      alignItems: "center"
    }
  }, /*#__PURE__*/React.createElement(Icon, {
    name: "Plus",
    size: 14,
    color: "var(--color-success)"
  }), l.match, " ", /*#__PURE__*/React.createElement("span", {
    style: {
      font: "var(--type-caption)",
      color: "var(--text-secondary)"
    }
  }, "new product")), l.state === "Skipped" && /*#__PURE__*/React.createElement("div", {
    style: {
      font: "var(--type-caption)",
      color: "var(--text-secondary)"
    }
  }, "Skipped \u2013 not received.")), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "grid",
      gridTemplateColumns: "80px 110px",
      gap: 8,
      alignContent: "start"
    }
  }, /*#__PURE__*/React.createElement(Input, {
    size: "sm",
    label: "Qty",
    type: "number",
    defaultValue: l.qty,
    suffix: l.unit
  }), /*#__PURE__*/React.createElement(Input, {
    size: "sm",
    label: "Unit price",
    defaultValue: l.price.toFixed(2),
    icon: "DollarSign"
  }))), l.state === "Matched" && i === 0 && /*#__PURE__*/React.createElement("div", {
    style: {
      marginTop: 14,
      paddingTop: 14,
      borderTop: "1px solid var(--color-line)",
      display: "grid",
      gridTemplateColumns: "repeat(3,minmax(0,1fr))",
      gap: 8
    }
  }, /*#__PURE__*/React.createElement(Input, {
    size: "sm",
    label: "Lot number",
    placeholder: "e.g. B441"
  }), /*#__PURE__*/React.createElement(Input, {
    size: "sm",
    label: "Expiry",
    type: "month"
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      alignSelf: "end",
      font: "var(--type-micro)",
      color: "var(--text-secondary)",
      paddingBottom: 10
    }
  }, "Skip now \u2192 appears under Missing expiry."))))), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "grid",
      gap: 16,
      position: "sticky",
      top: 96
    }
  }, /*#__PURE__*/React.createElement(Card, {
    eyebrow: "Invoice",
    padding: 20
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "grid",
      gap: 8,
      font: "var(--type-caption)",
      color: "var(--text-body)"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      font: "var(--type-body-sm-strong)",
      color: "var(--color-ink)"
    }
  }, I.supplier), /*#__PURE__*/React.createElement("div", null, I.number, " \xB7 ", I.date), /*#__PURE__*/React.createElement("div", {
    style: {
      height: 120,
      background: "var(--color-canvas-sunken)",
      borderRadius: "var(--radius-sm)",
      display: "grid",
      placeItems: "center",
      color: "var(--text-secondary)"
    }
  }, /*#__PURE__*/React.createElement(Icon, {
    name: "FileText",
    size: 28,
    color: "var(--color-mute)"
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      justifyContent: "space-between",
      borderTop: "1px solid var(--color-line)",
      paddingTop: 8
    }
  }, /*#__PURE__*/React.createElement("span", null, "Total"), /*#__PURE__*/React.createElement("b", {
    style: {
      color: "var(--color-ink)"
    }
  }, I.total)))), /*#__PURE__*/React.createElement(Card, {
    variant: "outline",
    padding: 20
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      font: "var(--type-caption)",
      color: "var(--text-body)",
      marginBottom: 12
    }
  }, lines.filter(l => l.state === "Matched" || l.state === "Created").length, " of ", lines.length, " lines will be received."), /*#__PURE__*/React.createElement(Button, {
    fullWidth: true,
    disabled: !ready,
    icon: "Check",
    onClick: () => {
      toast({
        tone: "success",
        title: "Delivery received",
        description: "Inventory increased for 3 products.",
        action: /*#__PURE__*/React.createElement(Button, {
          size: "sm",
          variant: "text"
        }, "Undo")
      });
      go("inv");
    }
  }, "Confirm & receive"), /*#__PURE__*/React.createElement("div", {
    style: {
      marginTop: 8
    }
  }, /*#__PURE__*/React.createElement(Button, {
    fullWidth: true,
    variant: "text",
    size: "sm",
    onClick: () => go("receive")
  }, "Receive manually instead"))))));
}
function ManualReceive({
  go,
  toast
}) {
  const P = window.MS.products;
  const [mode, setMode] = React.useState("manual");
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: "grid",
      gridTemplateColumns: "1fr 1fr",
      gap: 24,
      alignItems: "start"
    }
  }, /*#__PURE__*/React.createElement(Card, {
    eyebrow: "Receive delivery",
    title: "How did the supplies arrive?"
  }, /*#__PURE__*/React.createElement(Radio, {
    name: "rx",
    value: mode,
    onChange: setMode,
    options: [{
      value: "pdf",
      label: "Upload invoice PDF or image",
      description: "AI reads the line items, you review."
    }, {
      value: "photo",
      label: "Take a photo",
      description: "Phone camera."
    }, {
      value: "manual",
      label: "Receive manually",
      description: "Missing invoice or single items."
    }]
  }), mode !== "manual" && /*#__PURE__*/React.createElement("div", {
    style: {
      marginTop: 16
    }
  }, /*#__PURE__*/React.createElement(Button, {
    icon: "Upload",
    onClick: () => go("invoice")
  }, "Choose file"))), mode === "manual" && /*#__PURE__*/React.createElement(Card, {
    variant: "outline",
    title: "Receive inventory"
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "grid",
      gap: 12
    }
  }, /*#__PURE__*/React.createElement(Select, {
    label: "Product",
    options: P.map(p => p.name)
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "grid",
      gridTemplateColumns: "1fr 1fr",
      gap: 12
    }
  }, /*#__PURE__*/React.createElement(Input, {
    label: "Quantity",
    type: "number",
    defaultValue: "4"
  }), /*#__PURE__*/React.createElement(Input, {
    label: "Cost per unit",
    icon: "DollarSign",
    defaultValue: "45.00"
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "grid",
      gridTemplateColumns: "1fr 1fr",
      gap: 12
    }
  }, /*#__PURE__*/React.createElement(Input, {
    label: "Lot",
    placeholder: "Optional"
  }), /*#__PURE__*/React.createElement(Input, {
    label: "Expiry",
    type: "month"
  })), /*#__PURE__*/React.createElement(Button, {
    onClick: () => {
      toast({
        tone: "success",
        title: "4 kits received",
        description: "Endo file kit #15-40 · 1 → 5",
        action: /*#__PURE__*/React.createElement(Button, {
          size: "sm",
          variant: "text"
        }, "Undo")
      });
      go("inv");
    }
  }, "Receive"))));
}
window.InvoiceReview = InvoiceReview;
window.ManualReceive = ManualReceive;
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/app/InvoiceReview.jsx", error: String((e && e.message) || e) }); }

// ui_kits/app/Procedure.jsx
try { (() => {
const {
  Card,
  Badge,
  Button,
  Icon,
  Input,
  Dialog
} = window.MediSaveDesignSystem_1666cb;
function Procedure({
  toast
}) {
  const T = window.MS.procedures;
  const P = window.MS.products;
  const [sel, setSel] = React.useState("root");
  const [status, setStatus] = React.useState("new");
  const [actual, setActual] = React.useState({});
  const [cancel, setCancel] = React.useState(false);
  const t = T.find(x => x.id === sel);
  const avail = name => {
    const p = P.find(x => x.name === name);
    return p ? p.avail - p.reserved : 12;
  };
  const reset = () => {
    setStatus("new");
    setActual({});
  };
  return /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "grid",
      gridTemplateColumns: "260px 1fr",
      gap: 24,
      alignItems: "start"
    }
  }, /*#__PURE__*/React.createElement(Card, {
    padding: 8,
    eyebrow: null
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      font: "var(--type-eyebrow)",
      letterSpacing: 1,
      textTransform: "uppercase",
      color: "var(--text-secondary)",
      padding: "8px 12px 10px"
    }
  }, "Templates"), T.map(x => /*#__PURE__*/React.createElement("button", {
    key: x.id,
    onClick: () => {
      setSel(x.id);
      reset();
    },
    style: {
      all: "unset",
      cursor: "pointer",
      display: "flex",
      alignItems: "center",
      padding: "10px 12px",
      boxSizing: "border-box",
      width: "100%",
      borderRadius: "var(--radius-sm)",
      font: x.id === sel ? "var(--type-body-sm-strong)" : "var(--type-body-sm)",
      color: x.id === sel ? "var(--color-primary)" : "var(--color-ink)",
      background: x.id === sel ? "var(--surface-page)" : "transparent"
    }
  }, x.name, /*#__PURE__*/React.createElement("span", {
    style: {
      marginLeft: "auto",
      font: "var(--type-micro)",
      color: "var(--text-secondary)",
      whiteSpace: "nowrap"
    }
  }, x.items.length, " items"))), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: "10px 12px 4px"
    }
  }, /*#__PURE__*/React.createElement(Button, {
    variant: "text",
    size: "sm",
    icon: "Plus"
  }, "New template"))), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "grid",
      gap: 16
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "center",
      gap: 12
    }
  }, /*#__PURE__*/React.createElement("h2", {
    style: {
      font: "var(--type-display-md)",
      letterSpacing: 1
    }
  }, t.name), status !== "new" && /*#__PURE__*/React.createElement(Badge, {
    dot: true
  }, status === "prepared" ? "Prepared" : status === "done" ? "Completed" : "Cancelled"), /*#__PURE__*/React.createElement("span", {
    style: {
      marginLeft: "auto",
      font: "var(--type-caption)",
      color: "var(--text-secondary)"
    }
  }, "Starter quantities are templates, not clinical recommendations.")), /*#__PURE__*/React.createElement(Card, {
    padding: 0
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "grid",
      gridTemplateColumns: "1fr 90px 120px 1fr",
      gap: 12,
      padding: "12px 20px",
      font: "var(--type-caption-strong)",
      color: "var(--text-secondary)",
      borderBottom: "1px solid var(--color-line)"
    }
  }, /*#__PURE__*/React.createElement("span", null, "Expected supplies"), /*#__PURE__*/React.createElement("span", {
    style: {
      textAlign: "right"
    }
  }, "Expected"), /*#__PURE__*/React.createElement("span", {
    style: {
      textAlign: "right"
    }
  }, status === "prepared" ? "Actual" : ""), /*#__PURE__*/React.createElement("span", null, "Availability")), t.items.map(([name, q]) => {
    const a = avail(name);
    const remain = a - q;
    const tone = remain < 0 ? "danger" : remain <= 1 ? "warning" : "success";
    return /*#__PURE__*/React.createElement("div", {
      key: name,
      style: {
        display: "grid",
        gridTemplateColumns: "1fr 90px 120px 1fr",
        gap: 12,
        padding: "12px 20px",
        alignItems: "center",
        borderBottom: "1px solid var(--color-line)"
      }
    }, /*#__PURE__*/React.createElement("span", {
      style: {
        font: "var(--type-body-sm)",
        color: "var(--color-ink)"
      }
    }, name), /*#__PURE__*/React.createElement("span", {
      style: {
        textAlign: "right",
        font: "var(--type-body-sm-strong)"
      }
    }, q), /*#__PURE__*/React.createElement("span", {
      style: {
        textAlign: "right"
      }
    }, status === "prepared" && /*#__PURE__*/React.createElement(Input, {
      size: "sm",
      type: "number",
      value: actual[name] ?? q,
      onChange: e => setActual({
        ...actual,
        [name]: e.target.value
      }),
      style: {
        width: 80,
        marginLeft: "auto"
      }
    })), /*#__PURE__*/React.createElement("span", {
      style: {
        display: "flex",
        gap: 8,
        alignItems: "center",
        font: "var(--type-caption)",
        color: "var(--color-" + tone + ")"
      }
    }, /*#__PURE__*/React.createElement(Icon, {
      name: tone === "success" ? "Check" : "AlertTriangle",
      size: 14
    }), tone === "success" ? "OK" : remain < 0 ? "Not enough – " + a + " usable" : "Only " + remain + " will remain"));
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      gap: 8,
      justifyContent: "flex-end",
      padding: 16
    }
  }, status === "new" && /*#__PURE__*/React.createElement(Button, {
    icon: "ClipboardCheck",
    onClick: () => {
      setStatus("prepared");
      toast({
        tone: "neutral",
        title: "Root canal prepared",
        description: "6 items reserved. Usable inventory updated."
      });
    }
  }, "Prepare"), status === "prepared" && /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement(Button, {
    variant: "text",
    onClick: () => setCancel(true)
  }, "Cancel procedure"), /*#__PURE__*/React.createElement(Button, {
    variant: "secondary",
    onClick: () => {
      setStatus("done");
      toast({
        tone: "success",
        title: "Procedure completed",
        description: t.items.length + " items consumed",
        action: /*#__PURE__*/React.createElement(Button, {
          size: "sm",
          variant: "text"
        }, "Undo")
      });
    }
  }, "Complete \u2013 confirm usage")), (status === "done" || status === "cancelled") && /*#__PURE__*/React.createElement(Button, {
    variant: "tertiary",
    onClick: reset
  }, "Start another"))), status === "prepared" && /*#__PURE__*/React.createElement(Card, {
    padding: 16
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      gap: 32,
      font: "var(--type-caption)",
      color: "var(--text-body)"
    }
  }, /*#__PURE__*/React.createElement("span", null, "Septocaine \xB7 Available ", /*#__PURE__*/React.createElement("b", {
    style: {
      color: "var(--color-ink)"
    }
  }, "54")), /*#__PURE__*/React.createElement("span", null, "Reserved ", /*#__PURE__*/React.createElement("b", {
    style: {
      color: "var(--color-ink)"
    }
  }, "4")), /*#__PURE__*/React.createElement("span", null, "Usable available ", /*#__PURE__*/React.createElement("b", {
    style: {
      color: "var(--color-ink)"
    }
  }, "50")), /*#__PURE__*/React.createElement("span", {
    style: {
      marginLeft: "auto",
      color: "var(--text-secondary)"
    }
  }, "Reserved, not consumed, until you complete."))), /*#__PURE__*/React.createElement(Card, {
    eyebrow: "History",
    padding: 20
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "grid",
      gap: 8,
      font: "var(--type-caption)"
    }
  }, [["Oct 1", "Root canal", "Completed", "6 items consumed", "Sarah"], ["Oct 1", "Cleaning", "Completed", "4 items consumed", "Michael"], ["Sep 30", "Crown", "Cancelled", "reservations released", "Sarah"]].map((h, i) => /*#__PURE__*/React.createElement("div", {
    key: i,
    style: {
      display: "grid",
      gridTemplateColumns: "60px 1fr 110px 1fr 80px",
      gap: 12,
      alignItems: "center",
      color: "var(--text-body)"
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      color: "var(--text-secondary)"
    }
  }, h[0]), /*#__PURE__*/React.createElement("span", {
    style: {
      font: "var(--type-body-sm-strong)",
      color: "var(--color-ink)"
    }
  }, h[1]), /*#__PURE__*/React.createElement(Badge, {
    size: "sm"
  }, h[2]), /*#__PURE__*/React.createElement("span", null, h[3]), /*#__PURE__*/React.createElement("span", {
    style: {
      color: "var(--text-secondary)"
    }
  }, h[4]))))))), /*#__PURE__*/React.createElement(Dialog, {
    open: cancel,
    onClose: () => setCancel(false),
    title: "Cancel this procedure?",
    description: "Reservations are released and inventory does not decrease.",
    footer: /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement(Button, {
      variant: "text",
      onClick: () => setCancel(false)
    }, "Keep prepared"), /*#__PURE__*/React.createElement(Button, {
      variant: "danger",
      onClick: () => {
        setCancel(false);
        setStatus("cancelled");
      }
    }, "Cancel procedure"))
  }));
}
window.Procedure = Procedure;
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/app/Procedure.jsx", error: String((e && e.message) || e) }); }

// ui_kits/app/ProductDetail.jsx
try { (() => {
const {
  Card,
  Badge,
  Button,
  Tabs,
  Dialog,
  Input,
  Select,
  Icon
} = window.MediSaveDesignSystem_1666cb;
function Num({
  label,
  value,
  hint
}) {
  return /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement("div", {
    style: {
      font: "var(--type-caption)",
      color: "var(--text-secondary)"
    }
  }, label), /*#__PURE__*/React.createElement("div", {
    style: {
      font: "var(--type-display-xs)",
      letterSpacing: -0.5,
      marginTop: 4,
      color: "var(--color-ink)"
    }
  }, value), hint && /*#__PURE__*/React.createElement("div", {
    style: {
      font: "var(--type-micro)",
      color: "var(--text-secondary)"
    }
  }, hint));
}
function ProductDetail({
  p,
  go,
  toast
}) {
  const [adj, setAdj] = React.useState(false);
  const [tab, setTab] = React.useState("lots");
  const A = window.MS.activity.filter(a => a.product === p.name);
  return /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "flex-start",
      gap: 16
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      gap: 10,
      alignItems: "center"
    }
  }, /*#__PURE__*/React.createElement("h2", {
    style: {
      font: "var(--type-display-md)",
      letterSpacing: 1
    }
  }, p.name), /*#__PURE__*/React.createElement(Badge, {
    dot: true
  }, p.status)), /*#__PURE__*/React.createElement("div", {
    style: {
      font: "var(--type-caption)",
      color: "var(--text-secondary)",
      marginTop: 6
    }
  }, p.cat, " \xB7 ", p.mode, " tracked \xB7 $", p.cost.toFixed(2), " / ", p.unit.replace(/s$/, ""))), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      gap: 8
    }
  }, /*#__PURE__*/React.createElement(Button, {
    variant: "tertiary",
    size: "sm",
    icon: "SlidersHorizontal",
    onClick: () => setAdj(true)
  }, "Adjust"), /*#__PURE__*/React.createElement(Button, {
    variant: "tertiary",
    size: "sm",
    icon: "Truck",
    onClick: () => go("receive")
  }, "Receive"), /*#__PURE__*/React.createElement(Button, {
    variant: "tertiary",
    size: "sm",
    icon: "ListChecks"
  }, "Count"), /*#__PURE__*/React.createElement(Button, {
    size: "sm",
    icon: "ShoppingCart",
    onClick: () => toast({
      tone: "success",
      title: "Added to order list",
      description: p.name + " · suggested " + Math.max(p.target - (p.avail - p.reserved), 0) + " " + p.unit
    })
  }, "Add to order"))), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "grid",
      gridTemplateColumns: "2fr 1fr",
      gap: 24,
      alignItems: "start"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "grid",
      gap: 24
    }
  }, /*#__PURE__*/React.createElement(Card, null, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "grid",
      gridTemplateColumns: "repeat(5,1fr)",
      gap: 16
    }
  }, /*#__PURE__*/React.createElement(Num, {
    label: "Available",
    value: p.avail,
    hint: p.unit
  }), /*#__PURE__*/React.createElement(Num, {
    label: "Reserved",
    value: p.reserved,
    hint: "prepared procedures"
  }), /*#__PURE__*/React.createElement(Num, {
    label: "Usable",
    value: p.avail - p.reserved
  }), /*#__PURE__*/React.createElement(Num, {
    label: "Minimum",
    value: p.min
  }), /*#__PURE__*/React.createElement(Num, {
    label: "Target",
    value: p.target
  })), p.avail - p.reserved < p.target && /*#__PURE__*/React.createElement("div", {
    style: {
      marginTop: 16,
      padding: "10px 12px",
      background: "var(--color-warning-soft)",
      color: "var(--color-warning)",
      borderRadius: "var(--radius-sm)",
      font: "var(--type-caption-strong)",
      display: "flex",
      gap: 8,
      alignItems: "center"
    }
  }, /*#__PURE__*/React.createElement(Icon, {
    name: "AlertTriangle",
    size: 16
  }), "Recommended reorder: ", p.target - (p.avail - p.reserved), " ", p.unit, " (target \u2212 usable)")), /*#__PURE__*/React.createElement(Tabs, {
    items: [{
      id: "lots",
      label: "Lots",
      count: p.lots.length
    }, {
      id: "hist",
      label: "Transaction history",
      count: A.length
    }, {
      id: "usage",
      label: "Last 30 days"
    }],
    value: tab,
    onChange: setTab
  }), tab === "lots" && /*#__PURE__*/React.createElement("div", {
    style: {
      display: "grid",
      gap: 10
    }
  }, p.lots.length === 0 && /*#__PURE__*/React.createElement(Card, {
    padding: 32,
    style: {
      textAlign: "center",
      font: "var(--type-body-md)",
      color: "var(--text-secondary)"
    }
  }, "No lots recorded. Expiry is not tracked for this product."), p.lots.map((l, i) => /*#__PURE__*/React.createElement(Card, {
    key: l.lot,
    variant: i === 0 ? "outline" : "soft",
    padding: 16
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "center",
      gap: 16
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      font: "var(--type-mono-sm)",
      background: "var(--color-canvas-sunken)",
      padding: "2px 8px",
      borderRadius: 4
    }
  }, "LOT ", l.lot), /*#__PURE__*/React.createElement("span", {
    style: {
      font: "var(--type-body-sm-strong)"
    }
  }, l.qty, " ", p.unit), /*#__PURE__*/React.createElement("span", {
    style: {
      font: "var(--type-caption)",
      color: "var(--text-body)"
    }
  }, "Expires ", l.exp), i === 0 && /*#__PURE__*/React.createElement("span", {
    style: {
      marginLeft: "auto",
      font: "var(--type-caption-strong)",
      color: "var(--color-primary)",
      display: "flex",
      gap: 6,
      alignItems: "center"
    }
  }, /*#__PURE__*/React.createElement(Icon, {
    name: "ArrowDownToLine",
    size: 14
  }), "Use first (FEFO)")), i === 0 && /*#__PURE__*/React.createElement("div", {
    style: {
      font: "var(--type-micro)",
      color: "var(--text-secondary)",
      marginTop: 8
    }
  }, "Inventory assumption until staff confirm the lot physically used.")))), tab === "hist" && /*#__PURE__*/React.createElement(Card, {
    padding: 0
  }, A.map((a, i) => /*#__PURE__*/React.createElement("div", {
    key: i,
    style: {
      display: "grid",
      gridTemplateColumns: "140px 90px 1fr 90px",
      gap: 12,
      padding: "12px 20px",
      borderBottom: i < A.length - 1 ? "1px solid var(--color-line)" : "none",
      font: "var(--type-caption)",
      alignItems: "center"
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      color: "var(--text-secondary)"
    }
  }, a.when), /*#__PURE__*/React.createElement("span", {
    style: {
      font: "var(--type-body-sm-strong)",
      color: a.delta.startsWith("−") ? "var(--color-danger)" : "var(--color-ink)"
    }
  }, a.delta), /*#__PURE__*/React.createElement("span", null, "Reason: ", a.reason), /*#__PURE__*/React.createElement("span", {
    style: {
      color: "var(--text-secondary)"
    }
  }, "By ", a.by)))), tab === "usage" && /*#__PURE__*/React.createElement(Card, null, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "flex-end",
      gap: 6,
      height: 120
    }
  }, [3, 0, 2, 4, 1, 0, 0, 2, 3, 1, 2, 0, 0, 4, 2, 1, 3, 0, 0, 2, 1, 2, 4, 0, 0, 1, 3, 2, 1, 0].map((v, i) => /*#__PURE__*/React.createElement("div", {
    key: i,
    style: {
      flex: 1,
      height: v * 25 + 4,
      background: v ? "var(--color-primary)" : "var(--color-line)",
      borderRadius: 2
    }
  }))), /*#__PURE__*/React.createElement("div", {
    style: {
      font: "var(--type-caption)",
      color: "var(--text-body)",
      marginTop: 12
    }
  }, p.usage30, " ", p.unit, " consumed in the last 30 days from confirmed procedures."))), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "grid",
      gap: 16
    }
  }, /*#__PURE__*/React.createElement(Card, {
    eyebrow: "Reorder settings",
    padding: 20
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "grid",
      gap: 10
    }
  }, /*#__PURE__*/React.createElement(Input, {
    label: "Minimum",
    size: "sm",
    type: "number",
    defaultValue: p.min
  }), /*#__PURE__*/React.createElement(Input, {
    label: "Target",
    size: "sm",
    type: "number",
    defaultValue: p.target
  }), /*#__PURE__*/React.createElement(Select, {
    label: "Preferred supplier",
    size: "sm",
    options: ["Patterson", "Henry Schein", "Benco"]
  }))), /*#__PURE__*/React.createElement(Card, {
    eyebrow: "Supplier aliases",
    padding: 20
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "grid",
      gap: 6,
      font: "var(--type-caption)",
      color: "var(--text-body)"
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      font: "var(--type-mono-sm)"
    }
  }, "SEPTO 4% 1:100K 50/BX"), /*#__PURE__*/React.createElement("span", {
    style: {
      font: "var(--type-mono-sm)"
    }
  }, "SEPTOCAINE 1:100 BX50"), /*#__PURE__*/React.createElement("span", {
    style: {
      color: "var(--text-secondary)"
    }
  }, "Learned from invoices. Used to match future lines."))))), /*#__PURE__*/React.createElement(Dialog, {
    open: adj,
    onClose: () => setAdj(false),
    title: "Adjust inventory",
    description: "Enter the actual quantity. A reason is required and recorded in history.",
    footer: /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement(Button, {
      variant: "text",
      onClick: () => setAdj(false)
    }, "Cancel"), /*#__PURE__*/React.createElement(Button, {
      onClick: () => {
        setAdj(false);
        toast({
          tone: "success",
          title: "Inventory adjusted",
          description: p.name + " · " + p.avail + " → 41 · Physical count"
        });
      }
    }, "Save adjustment"))
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "grid",
      gap: 12
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      font: "var(--type-caption)",
      color: "var(--text-body)"
    }
  }, "System estimate: ", /*#__PURE__*/React.createElement("b", {
    style: {
      color: "var(--color-ink)"
    }
  }, p.avail), " ", p.unit), /*#__PURE__*/React.createElement(Input, {
    label: "Actual quantity",
    type: "number",
    defaultValue: "41",
    suffix: p.unit
  }), /*#__PURE__*/React.createElement(Select, {
    label: "Reason",
    options: ["Physical count", "Expired", "Damaged", "Waste", "Missing", "Returned", "Data correction", "Other"]
  }), /*#__PURE__*/React.createElement(Input, {
    label: "Note",
    placeholder: "Optional"
  }))));
}
window.ProductDetail = ProductDetail;
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/app/ProductDetail.jsx", error: String((e && e.message) || e) }); }

// ui_kits/app/Shell.jsx
try { (() => {
const {
  Icon,
  Badge,
  IconButton,
  Input
} = window.MediSaveDesignSystem_1666cb;
const NAV = [["dash", "LayoutDashboard", "Dashboard"], ["inv", "Package", "Inventory"], ["receive", "Truck", "Receive delivery"], ["proc", "ClipboardCheck", "Procedures"], ["order", "ShoppingCart", "Need to order", 6], ["count", "ListChecks", "Quick count", 4], ["log", "History", "Activity"], ["settings", "Settings", "Settings"]];
function Shell({
  screen,
  setScreen,
  title,
  crumbs,
  actions,
  children
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: "grid",
      gridTemplateColumns: "var(--sidebar-width) 1fr",
      minHeight: "100vh",
      background: "var(--surface-page)"
    }
  }, /*#__PURE__*/React.createElement("aside", {
    style: {
      background: "var(--surface-card)",
      borderRight: "1px solid var(--color-line)",
      padding: "20px 12px",
      display: "flex",
      flexDirection: "column",
      gap: 4,
      position: "sticky",
      top: 0,
      height: "100vh"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      padding: "4px 12px 20px",
      display: "flex",
      alignItems: "center",
      justifyContent: "space-between"
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      font: "500 24px/1 var(--font-display)",
      color: "var(--color-ink)"
    }
  }, "MediSave"), /*#__PURE__*/React.createElement(Badge, {
    size: "sm",
    tone: "info"
  }, "Trial")), NAV.map(([id, ic, label, count]) => {
    const on = screen === id || id === "inv" && screen === "product" || id === "receive" && screen === "invoice";
    return /*#__PURE__*/React.createElement("button", {
      key: id,
      onClick: () => setScreen(id),
      style: {
        all: "unset",
        cursor: "pointer",
        display: "flex",
        alignItems: "center",
        gap: 10,
        padding: "10px 12px",
        borderRadius: "var(--radius-sm)",
        font: on ? "var(--type-body-sm-strong)" : "var(--type-body-sm)",
        color: on ? "var(--color-primary)" : "var(--color-ink)",
        background: on ? "var(--color-primary-soft)" : "transparent",
        boxShadow: on ? "inset 3px 0 0 var(--color-primary)" : "none"
      }
    }, /*#__PURE__*/React.createElement(Icon, {
      name: ic,
      size: 18
    }), label, count && /*#__PURE__*/React.createElement("span", {
      style: {
        marginLeft: "auto",
        font: "var(--type-micro)",
        color: "var(--text-secondary)"
      }
    }, count));
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      marginTop: "auto",
      padding: 12,
      display: "flex",
      gap: 10,
      alignItems: "center"
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      width: 32,
      height: 32,
      borderRadius: "50%",
      background: "var(--color-ink)",
      color: "var(--text-on-dark)",
      display: "grid",
      placeItems: "center",
      font: "var(--type-micro)"
    }
  }, "SM"), /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement("div", {
    style: {
      font: "var(--type-caption-strong)",
      color: "var(--color-ink)"
    }
  }, window.MS.clinic), /*#__PURE__*/React.createElement("div", {
    style: {
      font: "var(--type-micro)",
      color: "var(--text-secondary)"
    }
  }, "Sarah \xB7 Inventory manager")))), /*#__PURE__*/React.createElement("main", {
    style: {
      minWidth: 0
    }
  }, /*#__PURE__*/React.createElement("header", {
    style: {
      height: 64,
      display: "flex",
      alignItems: "center",
      gap: 16,
      padding: "0 32px",
      borderBottom: "1px solid var(--color-line)",
      position: "sticky",
      top: 0,
      background: "var(--surface-page)",
      zIndex: 10
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      display: "flex",
      alignItems: "baseline",
      gap: 10
    }
  }, crumbs && /*#__PURE__*/React.createElement("span", {
    style: {
      font: "var(--type-caption)",
      color: "var(--text-secondary)"
    }
  }, crumbs, " /"), /*#__PURE__*/React.createElement("h1", {
    style: {
      font: "var(--type-sub-sm)",
      letterSpacing: -0.6
    }
  }, title)), /*#__PURE__*/React.createElement("div", {
    style: {
      width: 260
    }
  }, /*#__PURE__*/React.createElement(Input, {
    icon: "Search",
    placeholder: "Search products",
    size: "sm"
  })), /*#__PURE__*/React.createElement(IconButton, {
    icon: "Bell",
    label: "Notifications"
  }), actions), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: 32,
      maxWidth: "var(--container-max)",
      display: "grid",
      gap: 24
    }
  }, children)));
}
window.Shell = Shell;
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/app/Shell.jsx", error: String((e && e.message) || e) }); }

// ui_kits/app/data.js
try { (() => {
window.MS = {
  clinic: "Smile Dental",
  products: [{
    id: 1,
    name: "Septocaine 4% 1:100,000",
    cat: "Anesthetic",
    mode: "Unit",
    unit: "cartridges",
    avail: 54,
    reserved: 2,
    min: 20,
    target: 60,
    cost: 0.99,
    status: "Healthy",
    expiry: "Dec 2026",
    lots: [{
      lot: "A112",
      qty: 20,
      exp: "Dec 2026"
    }, {
      lot: "B441",
      qty: 34,
      exp: "Jul 2027"
    }],
    usage30: 38
  }, {
    id: 2,
    name: "Endo file kit #15-40",
    cat: "Endodontics",
    mode: "Unit",
    unit: "kits",
    avail: 1,
    reserved: 0,
    min: 3,
    target: 5,
    cost: 45,
    status: "Low",
    expiry: "—",
    lots: [],
    usage30: 6
  }, {
    id: 3,
    name: "Composite A2",
    cat: "Restorative",
    mode: "Unit",
    unit: "syringes",
    avail: 2,
    reserved: 0,
    min: 3,
    target: 6,
    cost: 28.5,
    status: "Low",
    expiry: "Mar 2027",
    lots: [{
      lot: "C09",
      qty: 2,
      exp: "Mar 2027"
    }],
    usage30: 9
  }, {
    id: 4,
    name: "Bonding agent",
    cat: "Restorative",
    mode: "Container",
    unit: "bottles",
    avail: 1,
    reserved: 0,
    min: 1,
    target: 2,
    cost: 82,
    status: "Expiring",
    expiry: "Nov 3 2026",
    lots: [{
      lot: "BA7",
      qty: 1,
      exp: "Nov 3 2026"
    }],
    usage30: 1
  }, {
    id: 5,
    name: "Nitrile gloves M",
    cat: "PPE",
    mode: "Package",
    unit: "boxes",
    avail: 14,
    reserved: 0,
    min: 6,
    target: 20,
    cost: 9.4,
    status: "Healthy",
    expiry: "—",
    lots: [],
    usage30: 11
  }, {
    id: 6,
    name: "Surface disinfectant",
    cat: "Sterilization",
    mode: "Container",
    unit: "bottles",
    avail: 3,
    reserved: 0,
    min: 2,
    target: 4,
    cost: 18,
    status: "Needs count",
    expiry: "—",
    lots: [],
    usage30: 2
  }, {
    id: 7,
    name: "Rubber dam latex-free",
    cat: "Endodontics",
    mode: "Unit",
    unit: "sheets",
    avail: 0,
    reserved: 0,
    min: 10,
    target: 36,
    cost: 1.2,
    status: "Out of stock",
    expiry: "—",
    lots: [],
    usage30: 14
  }, {
    id: 8,
    name: "Gutta percha F2",
    cat: "Endodontics",
    mode: "Unit",
    unit: "packs",
    avail: 7,
    reserved: 1,
    min: 3,
    target: 10,
    cost: 12,
    status: "Missing expiry",
    expiry: "—",
    lots: [],
    usage30: 4
  }, {
    id: 9,
    name: "Suction tips",
    cat: "Disposable",
    mode: "Package",
    unit: "bags",
    avail: 9,
    reserved: 0,
    min: 4,
    target: 12,
    cost: 6.5,
    status: "Healthy",
    expiry: "—",
    lots: [],
    usage30: 5
  }, {
    id: 10,
    name: "Alginate impression",
    cat: "Impression",
    unit: "bags",
    mode: "Unit",
    avail: 4,
    reserved: 0,
    min: 2,
    target: 6,
    cost: 14,
    status: "Healthy",
    expiry: "Aug 2027",
    lots: [{
      lot: "AL3",
      qty: 4,
      exp: "Aug 2027"
    }],
    usage30: 3
  }],
  procedures: [{
    id: "root",
    name: "Root canal",
    items: [["Septocaine 4% 1:100,000", 2], ["Needle 27g short", 1], ["Rubber dam latex-free", 1], ["Endo file kit #15-40", 1], ["Gutta percha F2", 1], ["Suction tips", 1]]
  }, {
    id: "clean",
    name: "Cleaning",
    items: [["Prophy paste", 1], ["Prophy angle", 1], ["Nitrile gloves M", 1], ["Suction tips", 1]]
  }, {
    id: "fill",
    name: "Filling",
    items: [["Septocaine 4% 1:100,000", 1], ["Composite A2", 1], ["Bonding agent", 1], ["Nitrile gloves M", 1]]
  }, {
    id: "crown",
    name: "Crown",
    items: [["Septocaine 4% 1:100,000", 2], ["Alginate impression", 1], ["Temporary cement", 1]]
  }, {
    id: "ext",
    name: "Extraction",
    items: [["Septocaine 4% 1:100,000", 2], ["Needle 27g short", 1], ["Gauze", 4]]
  }],
  invoice: {
    supplier: "Patterson Dental",
    number: "INV-10092",
    date: "Oct 1, 2026",
    total: "$449.00",
    lines: [{
      desc: "SEPTO 4% 1:100K 50/BX",
      match: "Septocaine 4% 1:100,000",
      state: "Matched",
      qty: 5,
      unit: "box",
      price: 49.80
    }, {
      desc: "ENDO FILE KIT 15-40 21MM",
      match: "Endo file kit #15-40",
      state: "Possible match",
      qty: 4,
      unit: "box",
      price: 45.00
    }, {
      desc: "TEMPBOND NE 1PK",
      match: "",
      state: "New product",
      qty: 1,
      unit: "pack",
      price: 26.40
    }, {
      desc: "HANDLING / FUEL SURCHARGE",
      match: "",
      state: "Needs review",
      qty: 1,
      unit: "",
      price: 4.80
    }]
  },
  activity: [{
    when: "Oct 1 · 4:22 PM",
    product: "Septocaine 4% 1:100,000",
    delta: "43 → 41",
    reason: "Physical count",
    by: "Michael"
  }, {
    when: "Oct 1 · 3:14 PM",
    product: "Septocaine 4% 1:100,000",
    delta: "−2",
    reason: "Root canal",
    by: "Sarah"
  }, {
    when: "Oct 1 · 9:02 AM",
    product: "Endo file kit #15-40",
    delta: "+4",
    reason: "Invoice INV-10092",
    by: "Michael"
  }, {
    when: "Sep 30 · 5:40 PM",
    product: "Bonding agent",
    delta: "Full → 50%",
    reason: "Update level",
    by: "Sarah"
  }]
};
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/app/data.js", error: String((e && e.message) || e) }); }

__ds_ns.Button = __ds_scope.Button;

__ds_ns.IconButton = __ds_scope.IconButton;

__ds_ns.Badge = __ds_scope.Badge;

__ds_ns.Card = __ds_scope.Card;

__ds_ns.Icon = __ds_scope.Icon;

__ds_ns.Tabs = __ds_scope.Tabs;

__ds_ns.Tag = __ds_scope.Tag;

__ds_ns.Dialog = __ds_scope.Dialog;

__ds_ns.Toast = __ds_scope.Toast;

__ds_ns.Tooltip = __ds_scope.Tooltip;

__ds_ns.Checkbox = __ds_scope.Checkbox;

__ds_ns.Input = __ds_scope.Input;

__ds_ns.Radio = __ds_scope.Radio;

__ds_ns.Select = __ds_scope.Select;

__ds_ns.Switch = __ds_scope.Switch;

})();
