package com.wedo.backend.activity.dto;

/** Derived server-side capability flags for the authenticated caller. */
public record ActivityPermissionFlags(boolean canEdit, boolean canConfirm, boolean canCancel,
                                      boolean canComplete, boolean canRsvp) { }
