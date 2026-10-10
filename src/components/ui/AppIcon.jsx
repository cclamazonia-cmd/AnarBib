import {
  Accessibility, Archive, ArchiveRestore, ArrowDownToLine, ArrowLeftRight, ArrowUpFromLine,
  Ban, Bell, BookMarked, BookOpen, Boxes, Building2, CalendarDays, Check,
  ClipboardList, FileText, Filter, FolderKanban, Gauge, Globe2, History, Image,
  Inbox, KeyRound, Landmark, LayoutDashboard, Library, Lightbulb, Link2, ListChecks,
  Mail, Map, Megaphone, Menu, MessageSquare, Network, NotebookPen, Package, Palette,
  Pencil, PenLine, Newspaper, Pin, Puzzle, Search, ScrollText, Send, Settings2, Shield, Star, Tags,
  Scale, Sparkles, Stamp, Target, Ticket, Trash2, Truck, User, Users, WandSparkles, Wrench,
  Zap, X, CircleAlert, CircleHelp, Info,
} from 'lucide-react';

const ICONS = {
  accessibility: Accessibility, archive: Archive, archiveRestore: ArchiveRestore,
  arrowDown: ArrowDownToLine,
  arrowLeftRight: ArrowLeftRight, arrowUp: ArrowUpFromLine, bell: Bell,
  book: BookOpen, bookmark: BookMarked, boxes: Boxes, building: Building2,
  calendar: CalendarDays, check: Check, clipboard: ClipboardList,
  document: FileText, filter: Filter, folder: FolderKanban, gauge: Gauge,
  globe: Globe2, history: History, image: Image, inbox: Inbox, key: KeyRound, landmark: Landmark,
  lightbulb: Lightbulb,
  dashboard: LayoutDashboard, library: Library, link: Link2, list: ListChecks,
  mail: Mail, map: Map, megaphone: Megaphone, menu: Menu, message: MessageSquare,
  network: Network, notebookPen: NotebookPen, package: Package, palette: Palette,
  pencil: Pencil, penLine: PenLine, pin: Pin, puzzle: Puzzle, newspaper: Newspaper,
  search: Search, scrollText: ScrollText, send: Send, settings: Settings2,
  shield: Shield, star: Star, tags: Tags, scale: Scale, sparkles: Sparkles,
  stamp: Stamp, target: Target, ticket: Ticket, trash: Trash2, truck: Truck,
  user: User, users: Users, wand: WandSparkles, warning: CircleAlert, ban: Ban,
  zap: Zap, wrench: Wrench, close: X, circleAlert: CircleAlert, help: CircleHelp, info: Info,
};

const warnedNames = new Set();

/** Neutral, monochrome interface icon. Lucide is ISC-licensed and renders as SVG. */
export default function AppIcon({ name, size = 18, strokeWidth = 1.8, className = '', title, style, fill }) {
  if (import.meta.env?.DEV && name && !ICONS[name] && !warnedNames.has(name)) {
    warnedNames.add(name);
    console.warn(`[AppIcon] Unknown icon name: ${name}`);
  }
  const Icon = ICONS[name] || Info;   // E32 (10/10/2026) : la table LEGACY des emojis est sortie — plus aucune déclaration d'icône n'en portait
  return <Icon className={className} style={style} size={size} strokeWidth={strokeWidth} fill={fill} role={title ? 'img' : undefined} aria-hidden={title ? undefined : true} aria-label={title} />;
}
