/**
 * doc-extractor.js
 * Parses LDoc-style comments from Lua source into structured documentation JSON.
 *
 * Recognized patterns (aligned with official Monome norns convention):
 *
 *   Script header (top of file):
 *     -- scriptname: description
 *     -- v1.0.0
 *     -- @author: name
 *     -- llllllll.co/t/thread-link
 *
 *   Section headers:
 *     -- @section Section Name
 *
 *   Function docs (LDoc triple-dash before function):
 *     --- Short description of the function.
 *     -- @tparam type param_name Description
 *     -- @treturn type Description
 *     local function my_fn(...)
 *
 *   Grid control maps (specific to grid scripts — common pattern):
 *     -- x=1..8: Fruit spawn count slider
 *     -- y=3, x=1: Autopilot mode toggle
 *     -- Row 3, col 1: Description
 *
 *   Variable state declarations (auto-extracted, no annotation needed):
 *     Extracts `local varname = value` lines for the "State" panel
 */

export class DocExtractor {
  /**
   * Parse a Lua source string into a structured docs object.
   * @param {string} source – full Lua file content
   * @returns {DocResult}
   */
  parse(source) {
    const lines = source.split('\n');
    const result = {
      meta: {
        name: '',
        description: '',
        version: '',
        author: '',
        link: ''
      },
      sections: [],
      functions: [],
      controls: [],
      state: []
    };

    // ── Script header (first non-empty block of -- comments) ──────────────
    result.meta = this._parseHeader(lines);

    // ── Sections, functions, controls ─────────────────────────────────────
    let currentSection = { title: 'General', description: '', functions: [], controls: [] };
    let pendingDoc = [];     // accumulated --- / -- @tparam lines before a function
    let pendingIsDoc = false;

    for (let i = 0; i < lines.length; i++) {
      const raw = lines[i];
      const trimmed = raw.trim();

      // Section marker: -- @section Title
      const sectionMatch = trimmed.match(/^--\s*@section\s+(.+)/);
      if (sectionMatch) {
        if (currentSection.functions.length > 0 || currentSection.controls.length > 0) {
          result.sections.push(currentSection);
        }
        currentSection = { title: sectionMatch[1].trim(), description: '', functions: [], controls: [] };
        pendingDoc = [];
        pendingIsDoc = false;
        continue;
      }

      // Triple-dash doc comment: --- description
      const tripleMatch = trimmed.match(/^---\s*(.*)/);
      if (tripleMatch) {
        if (!pendingIsDoc) pendingDoc = [];
        pendingIsDoc = true;
        pendingDoc.push({ type: 'desc', text: tripleMatch[1].trim() });
        continue;
      }

      // Double-dash param/return: -- @tparam / -- @treturn / -- @param
      if (pendingIsDoc) {
        const tparamMatch = trimmed.match(/^--\s*@tparam\s+(\S+)\s+(\S+)\s*(.*)/);
        const treturnMatch = trimmed.match(/^--\s*@treturn\s+(\S+)\s*(.*)/);
        const paramMatch = trimmed.match(/^--\s*@param\s+(\S+)\s*(.*)/);
        if (tparamMatch) {
          pendingDoc.push({ type: 'param', ptype: tparamMatch[1], name: tparamMatch[2], text: tparamMatch[3].trim() });
          continue;
        }
        if (treturnMatch) {
          pendingDoc.push({ type: 'return', ptype: treturnMatch[1], text: treturnMatch[2].trim() });
          continue;
        }
        if (paramMatch) {
          pendingDoc.push({ type: 'param', ptype: 'any', name: paramMatch[1], text: paramMatch[2].trim() });
          continue;
        }
        // Any other -- comment while in doc mode: continuation or end
        const contMatch = trimmed.match(/^--\s*(.*)/);
        if (contMatch && !trimmed.match(/^---/)) {
          // If not a @-tag, treat as continuation paragraph
          if (contMatch[1].trim() !== '') {
            pendingDoc.push({ type: 'note', text: contMatch[1].trim() });
          }
          continue;
        }
      }

      // Control map comment pattern: -- x=N..M: description  OR -- Row N: description
      const controlMatch = trimmed.match(/^--\s*((?:x=\d.*?|y=\d.*?|[Rr]ow\s+\d.*?|[Cc]ol(?:s?)\s*[\d\-]+.*?)):(.+)/);
      if (controlMatch) {
        currentSection.controls.push({
          location: controlMatch[1].trim(),
          description: controlMatch[2].trim()
        });
        result.controls.push({
          section: currentSection.title,
          location: controlMatch[1].trim(),
          description: controlMatch[2].trim()
        });
        pendingIsDoc = false;
        pendingDoc = [];
        continue;
      }

      // Function declaration (local or global)
      const fnMatch = trimmed.match(/^(?:local\s+)?function\s+([a-zA-Z_][a-zA-Z0-9_.]*)\s*\(([^)]*)\)/);
      if (fnMatch && pendingIsDoc && pendingDoc.length > 0) {
        const fnDoc = this._buildFnDoc(fnMatch[1], fnMatch[2], pendingDoc);
        currentSection.functions.push(fnDoc);
        result.functions.push({ ...fnDoc, section: currentSection.title });
        pendingDoc = [];
        pendingIsDoc = false;
        continue;
      }

      // Any non-comment, non-blank line ends pending doc if not followed by function
      if (trimmed !== '' && !trimmed.startsWith('--')) {
        pendingDoc = [];
        pendingIsDoc = false;
      }

      // State variable extraction: local varname = value (simple scalars only)
      const stateMatch = trimmed.match(/^local\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*=\s*([^{(\n]+)/);
      if (stateMatch && !trimmed.includes('function')) {
        const val = stateMatch[2].trim().replace(/--.*$/, '').trim();
        // Only capture simple values (numbers, booleans, strings, not tables)
        if (/^[\d"'truefalse\-]/.test(val) && val.length < 60) {
          result.state.push({ name: stateMatch[1], default: val });
        }
      }
    }

    // Push final section
    if (currentSection.functions.length > 0 || currentSection.controls.length > 0) {
      result.sections.push(currentSection);
    }

    return result;
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  _parseHeader(lines) {
    const meta = { name: '', description: '', version: '', author: '', link: '' };
    let inHeader = false;
    for (const line of lines) {
      const t = line.trim();
      if (!t.startsWith('--')) {
        if (inHeader) break;
        continue;
      }
      inHeader = true;
      const content = t.replace(/^--\s*/, '');

      const nameMatch = content.match(/^scriptname:\s*(.+)/i);
      if (nameMatch) { meta.name = nameMatch[1].trim(); continue; }

      const versionMatch = content.match(/^v(\d+\.\d+[\w.]*)/);
      if (versionMatch) { meta.version = 'v' + versionMatch[1]; continue; }

      const authorMatch = content.match(/^@author[:\s]+(.+)/i);
      if (authorMatch) { meta.author = authorMatch[1].trim(); continue; }

      const linkMatch = content.match(/(llllllll\.co\/t\/\S+|https?:\/\/\S+)/);
      if (linkMatch) { meta.link = linkMatch[1]; continue; }

      // First untagged line after scriptname becomes description
      if (!meta.description && meta.name && content && !content.startsWith('@')) {
        meta.description = content;
      }
    }
    return meta;
  }

  _buildFnDoc(name, paramsRaw, docTokens) {
    const desc = docTokens.filter(d => d.type === 'desc').map(d => d.text).join(' ');
    const params = docTokens.filter(d => d.type === 'param');
    const returns = docTokens.filter(d => d.type === 'return');
    const notes = docTokens.filter(d => d.type === 'note').map(d => d.text);
    return {
      name,
      signature: `${name}(${paramsRaw.trim()})`,
      description: desc,
      params,
      returns,
      notes
    };
  }
}
