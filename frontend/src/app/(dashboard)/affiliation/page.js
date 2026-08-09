'use client';

import React, { Suspense } from 'react';
import Affiliation from '../../../views/Affiliation';

export default function AffiliationPage() {
  return (
    <Suspense fallback={<div className="text-sm text-gray-500">Chargement...</div>}>
      <Affiliation />
    </Suspense>
  );
}
