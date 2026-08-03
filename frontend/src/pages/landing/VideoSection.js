function GridMarker({ type = 'cross', className }) {
  const lines = {
    cross: [<line key="v" x1="6" y1="0" x2="6" y2="12" />, <line key="h" x1="0" y1="6" x2="12" y2="6" />],
    'tee-down': [<line key="v" x1="6" y1="6" x2="6" y2="12" />, <line key="h" x1="0" y1="6" x2="12" y2="6" />],
    'tee-up': [<line key="v" x1="6" y1="0" x2="6" y2="6" />, <line key="h" x1="0" y1="6" x2="12" y2="6" />],
    'tee-right': [<line key="v" x1="6" y1="0" x2="6" y2="12" />, <line key="h" x1="6" y1="6" x2="12" y2="6" />],
    'tee-left': [<line key="v" x1="6" y1="0" x2="6" y2="12" />, <line key="h" x1="0" y1="6" x2="6" y2="6" />],
  };
  return (
    <svg className={`absolute w-4 h-4 text-[#6c6f7680] z-10 pointer-events-none ${className}`} viewBox="0 0 12 12" fill="none" stroke="currentColor" strokeWidth="1.5">
      {lines[type]}
    </svg>
  );
}

export default function VideoSection() {
  return (
    <section className="w-full bg-white relative py-20 lg:py-28 px-4 sm:px-6 overflow-x-clip">
      <div className="max-w-6xl mx-auto w-full">

        <div className="relative w-full overflow-visible">

          {/* Full-width horizontal rails */}
          <div className="absolute top-0 left-1/2 -translate-x-1/2 w-screen border-t border-[#6c6f7635] z-10 pointer-events-none" />
          <div className="absolute bottom-0 left-1/2 -translate-x-1/2 w-screen border-b border-[#6c6f7635] z-10 pointer-events-none" />

          {/* Vertical rails at edges */}
          <div className="absolute left-0 top-0 w-px h-full bg-[#6c6f7635] z-10 pointer-events-none" />
          <div className="absolute right-0 top-0 w-px h-full bg-[#6c6f7635] z-10 pointer-events-none" />

          {/* Grid markers at corners */}
          <GridMarker type="tee-down" className="top-0 left-0 -translate-x-1/2 -translate-y-1/2" />
          <GridMarker type="tee-down" className="top-0 right-0 translate-x-1/2 -translate-y-1/2" />
          <GridMarker type="tee-up" className="bottom-0 left-0 -translate-x-1/2 translate-y-1/2" />
          <GridMarker type="tee-up" className="bottom-0 right-0 translate-x-1/2 translate-y-1/2" />

          <div className="flex flex-col lg:flex-row relative z-0">

            {/* Text block */}
            <div className="flex flex-col gap-3 p-8 lg:p-12 lg:w-[55%] shrink-0 justify-center border-b lg:border-b-0 lg:border-r border-[#6c6f7635]">
              <h2 className="text-[#181818] text-lg md:text-xl lg:text-2xl font-semibold leading-tight">
                Voyez Autocontable<br />en action
              </h2>
              <p className="text-[#6b7280] text-xs md:text-sm leading-relaxed mt-3 max-w-sm">
                De la réception d'une facture par email à l'écriture comptable dans Sage — en 2 minutes. Pas de saisie, pas d'erreur, pas de stress.
              </p>
            </div>

            {/* Video */}
            <div className="relative lg:w-[45%] w-full shrink-0 bg-[#fafafa] min-h-[200px] sm:min-h-[280px]">
              <iframe
                width="100%"
                height="100%"
                src="https://www.youtube.com/embed/dQw4w9WgXcQ?controls=0"
                title="Démo Autocontable"
                frameBorder="0"
                allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
                referrerPolicy="strict-origin-when-cross-origin"
                allowFullScreen
                className="absolute inset-0 w-full h-full"
              />
            </div>

          </div>
        </div>
      </div>
    </section>
  );
}
