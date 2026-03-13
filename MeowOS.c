#include <gtk/gtk.h>
#include <vte/vte.h>
#include <stdlib.h>
#include <stdio.h>
#include <time.h>
#include <string.h>

// Struktura pro hlavní aplikaci
typedef struct {
    GtkWidget *window;
    GtkWidget *clock_label;
    guint clock_timeout;
} MeowOS;

// Deklarace funkcí
gboolean update_clock(gpointer data);
gboolean update_clock_label(gpointer data);
void open_terminal(GtkWidget *widget, gpointer data);
void open_clock(GtkWidget *widget, gpointer data);
void open_settings(GtkWidget *widget, gpointer data);
void open_file_manager(GtkWidget *widget, gpointer data);
void show_about_dialog(GtkWidget *widget, gpointer data);
void quit_application(GtkWidget *widget, gpointer data);
void show_menu(GtkWidget *widget, gpointer data);

// ============================================================================
// Funkce pro aktualizaci hodin v horní liště
// ============================================================================
gboolean update_clock(gpointer data) {
    MeowOS *os = (MeowOS *)data;
    time_t rawtime;
    struct tm *timeinfo;
    char buffer[64];

    time(&rawtime);
    timeinfo = localtime(&rawtime);
    strftime(buffer, sizeof(buffer), "%H:%M:%S", timeinfo);
    gtk_label_set_text(GTK_LABEL(os->clock_label), buffer);
    return G_SOURCE_CONTINUE;
}

// ============================================================================
// Funkce pro aktualizaci labelu v okně Hodiny
// ============================================================================
gboolean update_clock_label(gpointer data) {
    GtkWidget *label = GTK_WIDGET(data);
    time_t rawtime;
    struct tm *timeinfo;
    char buffer[64];
    char markup[128];

    time(&rawtime);
    timeinfo = localtime(&rawtime);
    strftime(buffer, sizeof(buffer), "%H:%M:%S", timeinfo);
    snprintf(markup, sizeof(markup), "<span font='40' foreground='white'>%s</span>", buffer);
    gtk_label_set_markup(GTK_LABEL(label), markup);
    return G_SOURCE_CONTINUE;
}

// ============================================================================
// Aplikace: Terminál
// ============================================================================
void open_terminal(GtkWidget *widget, gpointer data) {
    GtkWidget *term_window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
    gtk_window_set_title(GTK_WINDOW(term_window), "Terminál");
    gtk_window_set_default_size(GTK_WINDOW(term_window), 600, 400);

    VteTerminal *terminal = VTE_TERMINAL(vte_terminal_new());
    gtk_container_add(GTK_CONTAINER(term_window), GTK_WIDGET(terminal));

    const gchar *shell = g_getenv("SHELL");
    if (!shell) shell = "/bin/bash";

    vte_terminal_spawn_async(terminal,
                             VTE_PTY_DEFAULT,
                             NULL,
                             (char *[]){ (char *)shell, NULL },
                             NULL,
                             G_SPAWN_SEARCH_PATH,
                             NULL, NULL, NULL,
                             -1, NULL, NULL, NULL);

    gtk_widget_show_all(term_window);
}

// ============================================================================
// Aplikace: Hodiny
// ============================================================================
void open_clock(GtkWidget *widget, gpointer data) {
    GtkWidget *clock_window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
    gtk_window_set_title(GTK_WINDOW(clock_window), "Hodiny");
    gtk_window_set_default_size(GTK_WINDOW(clock_window), 300, 150);

    GtkWidget *label = gtk_label_new(NULL);
    gtk_label_set_markup(GTK_LABEL(label), "<span font='40' foreground='white'>00:00:00</span>");
    gtk_container_add(GTK_CONTAINER(clock_window), label);

    g_timeout_add_seconds(1, update_clock_label, label);
    update_clock_label(label);

    gtk_widget_show_all(clock_window);
}

// ============================================================================
// Aplikace: Nastavení (placeholder)
// ============================================================================
void open_settings(GtkWidget *widget, gpointer data) {
    GtkWidget *settings_window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
    gtk_window_set_title(GTK_WINDOW(settings_window), "Nastavení");
    gtk_window_set_default_size(GTK_WINDOW(settings_window), 400, 300);

    GtkWidget *label = gtk_label_new("Zde budou nastavení");
    gtk_container_add(GTK_CONTAINER(settings_window), label);

    gtk_widget_show_all(settings_window);
}

// ============================================================================
// Aplikace: Souborový manažer (pcmanfm)
// ============================================================================
void open_file_manager(GtkWidget *widget, gpointer data) {
    g_spawn_command_line_async("pcmanfm", NULL);
}

// ============================================================================
// Dialog O aplikaci
// ============================================================================
void show_about_dialog(GtkWidget *widget, gpointer data) {
    GtkWidget *dialog = gtk_message_dialog_new(GTK_WINDOW(data),
                                                GTK_DIALOG_DESTROY_WITH_PARENT,
                                                GTK_MESSAGE_INFO,
                                                GTK_BUTTONS_OK,
                                                "MeowOS\nVerze 1.0\nDesktop pro RPi Zero 2W\nVytvořeno v C + GTK");
    gtk_dialog_run(GTK_DIALOG(dialog));
    gtk_widget_destroy(dialog);
}

// ============================================================================
// Zobrazení menu při kliknutí na tlačítko
// ============================================================================
void show_menu(GtkWidget *widget, gpointer data) {
    GtkWidget *menu = gtk_menu_new();
    GtkWidget *about_item = gtk_menu_item_new_with_label("O aplikaci");
    g_signal_connect(about_item, "activate", G_CALLBACK(show_about_dialog), data);
    gtk_menu_shell_append(GTK_MENU_SHELL(menu), about_item);

    GtkWidget *separator = gtk_separator_menu_item_new();
    gtk_menu_shell_append(GTK_MENU_SHELL(menu), separator);

    GtkWidget *quit_item = gtk_menu_item_new_with_label("Konec");
    g_signal_connect(quit_item, "activate", G_CALLBACK(quit_application), data);
    gtk_menu_shell_append(GTK_MENU_SHELL(menu), quit_item);

    gtk_widget_show_all(menu);
    gtk_menu_popup(GTK_MENU(menu), NULL, NULL, NULL, NULL, 0, gtk_get_current_event_time());
}

// ============================================================================
// Ukončení aplikace
// ============================================================================
void quit_application(GtkWidget *widget, gpointer data) {
    MeowOS *os = (MeowOS *)data;
    if (os->clock_timeout > 0)
        g_source_remove(os->clock_timeout);
    gtk_main_quit();
}

// ============================================================================
// Vytvoření horní lišty s menu (kompatibilní se staršími GTK)
// ============================================================================
GtkWidget *create_topbar(MeowOS *os) {
    GtkWidget *topbar = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 5);
    gtk_widget_set_name(topbar, "topbar");

    // Tlačítko menu (logo) – obyčejné tlačítko, které otevře menu
    GtkWidget *menu_btn = gtk_button_new_with_label("🐱");
    gtk_widget_set_name(menu_btn, "menu-button");
    g_signal_connect(menu_btn, "clicked", G_CALLBACK(show_menu), os);
    gtk_box_pack_start(GTK_BOX(topbar), menu_btn, FALSE, FALSE, 5);

    // Hodiny – umístění doprostřed
    os->clock_label = gtk_label_new(NULL);
    update_clock(os);
    os->clock_timeout = g_timeout_add_seconds(1, update_clock, os);
    gtk_box_pack_start(GTK_BOX(topbar), os->clock_label, TRUE, TRUE, 0);
    gtk_widget_set_halign(os->clock_label, GTK_ALIGN_CENTER);

    // Systémové ikony vpravo
    GtkWidget *wifi_icon = gtk_image_new_from_icon_name("network-wireless-symbolic", GTK_ICON_SIZE_MENU);
    GtkWidget *battery_icon = gtk_image_new_from_icon_name("battery-good-symbolic", GTK_ICON_SIZE_MENU);
    GtkWidget *right_box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 5);
    gtk_box_pack_end(GTK_BOX(right_box), battery_icon, FALSE, FALSE, 5);
    gtk_box_pack_end(GTK_BOX(right_box), wifi_icon, FALSE, FALSE, 5);
    gtk_box_pack_end(GTK_BOX(topbar), right_box, FALSE, FALSE, 5);

    return topbar;
}

// ============================================================================
// Vytvoření docku
// ============================================================================
GtkWidget *create_dock(MeowOS *os) {
    GtkWidget *dock = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 10);
    gtk_widget_set_name(dock, "dock");
    gtk_widget_set_halign(dock, GTK_ALIGN_CENTER);
    gtk_widget_set_valign(dock, GTK_ALIGN_END);

    GtkWidget *term_btn = gtk_button_new_with_label("Term");
    g_signal_connect(term_btn, "clicked", G_CALLBACK(open_terminal), NULL);
    gtk_box_pack_start(GTK_BOX(dock), term_btn, FALSE, FALSE, 5);

    GtkWidget *clock_btn = gtk_button_new_with_label("Hod");
    g_signal_connect(clock_btn, "clicked", G_CALLBACK(open_clock), NULL);
    gtk_box_pack_start(GTK_BOX(dock), clock_btn, FALSE, FALSE, 5);

    GtkWidget *settings_btn = gtk_button_new_with_label("Nast");
    g_signal_connect(settings_btn, "clicked", G_CALLBACK(open_settings), NULL);
    gtk_box_pack_start(GTK_BOX(dock), settings_btn, FALSE, FALSE, 5);

    GtkWidget *file_btn = gtk_button_new_with_label("Soub");
    g_signal_connect(file_btn, "clicked", G_CALLBACK(open_file_manager), NULL);
    gtk_box_pack_start(GTK_BOX(dock), file_btn, FALSE, FALSE, 5);

    return dock;
}

// ============================================================================
// Hlavní funkce
// ============================================================================
int main(int argc, char *argv[]) {
    gtk_init(&argc, &argv);

    MeowOS *os = g_malloc(sizeof(MeowOS));

    os->window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
    gtk_window_set_title(GTK_WINDOW(os->window), "MeowOS");
    gtk_window_fullscreen(GTK_WINDOW(os->window));
    g_signal_connect(os->window, "destroy", G_CALLBACK(quit_application), os);

    GtkWidget *vbox = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);
    gtk_container_add(GTK_CONTAINER(os->window), vbox);

    GtkWidget *topbar = create_topbar(os);
    gtk_box_pack_start(GTK_BOX(vbox), topbar, FALSE, FALSE, 0);

    GtkWidget *desktop = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);
    gtk_widget_set_name(desktop, "desktop");
    gtk_box_pack_start(GTK_BOX(vbox), desktop, TRUE, TRUE, 0);

    GtkWidget *dock = create_dock(os);
    gtk_box_pack_start(GTK_BOX(vbox), dock, FALSE, FALSE, 0);

    // CSS styly
    GtkCssProvider *provider = gtk_css_provider_new();
    gtk_css_provider_load_from_data(provider,
        "#topbar {"
        "   background: rgba(20, 20, 30, 200);"
        "   color: white;"
        "   padding: 5px;"
        "}"
        "#dock {"
        "   background: rgba(30, 30, 40, 200);"
        "   border-radius: 20px;"
        "   padding: 10px;"
        "   margin: 10px;"
        "}"
        "#dock button {"
        "   background: rgba(60, 60, 80, 150);"
        "   color: white;"
        "   border: none;"
        "   border-radius: 10px;"
        "   padding: 8px 15px;"
        "}"
        "#dock button:hover {"
        "   background: rgba(100, 100, 140, 200);"
        "}"
        "#desktop {"
        "   background: rgba(30, 30, 40, 255);"
        "}"
        "#menu-button {"
        "   background: none;"
        "   color: white;"
        "   font-size: 20px;"
        "   border: none;"
        "   padding: 0 10px;"
        "}"
        , -1, NULL);

    gtk_style_context_add_provider_for_screen(gdk_screen_get_default(),
                                              GTK_STYLE_PROVIDER(provider),
                                              GTK_STYLE_PROVIDER_PRIORITY_APPLICATION);

    gtk_widget_show_all(os->window);
    gtk_main();

    g_free(os);
    return 0;
}
